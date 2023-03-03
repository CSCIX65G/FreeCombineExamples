//
//  Channel.swift
//  
//
//  Created by Van Simmons on 11/28/22.
//

import Core
import Atomics
import DequeModule

/*:
 AsyncStream/AsyncSequence problems:

 1. AsyncSequence _assumes_ blocking read only.

 2. Documented semantics of AsyncSequence require blocking

 3. There is no AsyncGenerator, i.e. a blocking write/non-blocking read

 4. AsyncStream is:
    a. Unfair in multi-consumer situations, i.e. consume requests are not queued.
    b. Blocking consumer only
    c. Non-blocking producer only

    These are not always what you want

 5. Cancelled tasks cannot await on an empty AsyncStreams
 */

public final class Channel<Value: Sendable>: @unchecked Sendable {
    public enum Result: Sendable {
        case value(Value)
        case completion(Channels.Completion)

        func get() throws -> Value {
            switch self {
                case let .value(value): return value
                case let .completion(completion): throw completion.error
            }
        }
    }

    private struct Error: Swift.Error {
        let wrapper: State
    }

    private struct WriterNode {
        let resumption: Resumption<Void>?
        let value: Channel<Value>.Result
    }

    private final class State: AtomicReference, Sendable {
        let completion: Channels.Completion?
        let readers: PersistentQueue<Resumption<Value>>
        let writers: PersistentQueue<WriterNode>

        init(
            completion: Channels.Completion? = .none,
            readers: PersistentQueue<Resumption<Value>> = .init(),
            writers: PersistentQueue<WriterNode> = .init()
        ) {
            self.completion = completion
            self.readers = readers
            self.writers = writers
        }

        init(_ value: Value) {
            completion = .none
            readers = .init()
            writers = PersistentQueue<WriterNode>(.init(resumption: .none, value: .value(value)))
        }
    }

    private let buffering: Channels.Buffering
    private let wrapped: ManagedAtomic<State>

    public init(buffering: Channels.Buffering = .unbounded, _ value: Value? = .none) {
        self.buffering = buffering
        self.wrapped = value == nil ? ManagedAtomic(State()) : ManagedAtomic(State(value!))
    }

    public func cancel(with error: Swift.Error = CancellationError()) throws -> Void {
        try wrapped.update(
            validate: checkStatus,
            next: { _ in .init(completion: .failure(error), readers: .init(), writers: .init()) },
            performAfter: { localState in
                localState.readers.forEach { try! $0.resume(throwing: error) }
                localState.writers.forEach { try! $0.resumption?.resume(throwing: error) }
            }
        )
    }

    public func write() async throws -> Void where Value == Void {
        try await write(.value(()))
    }

    /*:
     write a value and block until that value is read
     throws if the channel is completed or if writing the value causes a value to be dropped
     if a blocked writer is dropped, it handles the drop, if the write was non-blocking the current
     writer handles the drop
     */
    public func write(_ value: Channel<Value>.Result) async throws -> Void {
        var localState = wrapped.load(ordering: .relaxed)
        while true {
            try checkStatus(localState)
            let (dequeued, newReaders) = localState.readers.dequeue()
            switch dequeued {
                case .none:
                    guard let nextLocalWrapped = try await enqueueForWriting(localState, value) else {
                        return
                    }
                    localState = nextLocalWrapped
                case let .some(reader):
                    let (success, newLocalState) = wrapped.compareExchange(
                        expected: localState,
                        desired: .init(readers: newReaders, writers: localState.writers),
                        ordering: .relaxed
                    )
                    guard success else {
                        localState = newLocalState
                        continue
                    }
                    switch value {
                        case let .value(v):
                            try! reader.resume(returning: v)
                        case let .completion(completion):
                            try! reader.resume(throwing: completion.error)
                    }
                    return
            }
        }
    }

    public func write() throws -> Void where Value == Void {
        try write(.value(()))
    }

    // Non-blocking write
    public func write(_ value: Channel<Value>.Result) throws -> Void {
        var localState = wrapped.load(ordering: .relaxed)
        while true {
            try checkStatus(localState)
            let (dequeued, newReaders) = localState.readers.dequeue()
            switch dequeued {
                case .none:
                    guard let nextLocalWrapped = try enqueueAsValue(localState, value) else {
                        return
                    }
                    localState = nextLocalWrapped
                case let .some(reader):
                    let (success, newLocalState) = wrapped.compareExchange(
                        expected: localState,
                        desired: .init(readers: newReaders, writers: localState.writers),
                        ordering: .relaxed
                    )
                    guard success else {
                        localState = newLocalState
                        continue
                    }
                    switch value {
                        case let .value(v): try! reader.resume(returning: v)
                        case let .completion(completion): try! reader.resume(throwing: completion.error)
                    }
                    return
            }
        }
    }

    public func read() async throws -> Value {
        var localState = wrapped.load(ordering: .acquiring)
        while true {
            try checkStatus(localState)
            let (dequeued, newWriters) = localState.writers.dequeue()
            switch dequeued {
                case .none:
                    do { return try await enqueueForReading(&localState) }
                    catch { }
                case let .some(writerNode):
                    let (success, newLocalState) = wrapped.compareExchange(
                        expected: localState,
                        desired: .init(readers: localState.readers, writers: newWriters),
                        ordering: .releasing
                    )
                    guard success else {
                        localState = newLocalState
                        continue
                    }
                    try? writerNode.resumption?.resume()
                    return try writerNode.value.get()
            }
        }
    }

    public func read() throws -> Value {
        var localState = wrapped.load(ordering: .acquiring)
        while true {
            try checkStatus(localState)
            let (dequeued, newWriters) = localState.writers.dequeue()
            switch dequeued {
                case .none:
                    throw FailedReadError()
                case let .some(writerNode):
                    let (success, newLocalState) = wrapped.compareExchange(
                        expected: localState,
                        desired: .init(readers: localState.readers, writers: newWriters),
                        ordering: .releasing
                    )
                    guard success else {
                        localState = newLocalState
                        continue
                    }
                    try? writerNode.resumption?.resume()
                    return try writerNode.value.get()
            }
        }
    }

    private func checkStatus(_ localState: State) throws -> Void {
        guard localState.completion == nil else {
            switch localState.completion! {
                case .finished:
                    throw ChannelCompleteError(completion: localState.completion!)
                case let .failure(error):
                    throw error
            }
        }
    }

    private func enqueueAsValue(_ localState: State, _ value: Channel<Value>.Result) throws -> State? {
        let (dropped, writers) = localState.writers.enqueue(.init(resumption: .none, value: value))
        let (success, newLocalState) = wrapped.compareExchange(
            expected: localState,
            desired: State(readers: localState.readers, writers: writers),
            ordering: .relaxed
        )
        switch (success, dropped) {
            case (true, .none):
                return .none
            case let (true, .some(dropped)):
                if dropped.resumption == nil {
                    throw ChannelDroppedValueError(value: dropped.value)
                } else {
                    try? dropped.resumption?.resume(throwing: ChannelDroppedWriteError())
                    return .none
                }
            case (false, _):
                return newLocalState
        }
    }

    private func enqueueForWriting(_ localState: State, _ value: Channel<Value>.Result) async throws -> State? {
        do {
            let _: Void = try await pause { resumption in
                let (dropped, writers) = localState.writers.enqueue(.init(resumption: resumption, value: value))
                let (success, newLocalState) = wrapped.compareExchange(
                    expected: localState,
                    desired: State(readers: localState.readers, writers: writers),
                    ordering: .relaxed
                )
                switch (success, dropped) {
                    case (true, .none):
                        ()
                    case let (true, .some(dropped)):
                        dropped.resumption == nil
                        ? try! resumption.resume(throwing: ChannelDroppedValueError(value: dropped.value))
                        : try! dropped.resumption?.resume(throwing: ChannelDroppedWriteError())
                    case (false, _):
                        try! resumption.resume(
                            throwing: Error(wrapper: newLocalState)
                        )
                }
            }
            return .none
        } catch {
            guard let error = error as? Error else { throw error }
            return error.wrapper
        }
    }

    private func enqueueForReading(_ localState: inout Channel<Value>.State) async throws -> Value {
        try await pause { resumption in
            let (_, readers) = localState.readers.enqueue(resumption)
            let newVar = State(readers: readers, writers: localState.writers)
            let (success, newLocalState) = wrapped.compareExchange(
                expected: localState,
                desired: newVar,
                ordering: .sequentiallyConsistent
            )
            guard !success else { return }
            localState = newLocalState
            try! resumption.resume(throwing: Error(wrapper: newLocalState))
        }
    }
}
