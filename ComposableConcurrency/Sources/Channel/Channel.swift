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

 1. AsyncSequence _assumes_ blocking read only.  Documented semantics of AsyncSequence require blocking

 2. There is no AsyncGenerator

 2. AsyncStream is:
    a. Unfair in multi-consumer situations, i.e. consume requests are not queued.
    b. Blocking consumer only
    c. Non-blocking producer only

    These are not always what you want

 3. Cancelled tasks cannot wait empty AsyncStreams
 */

public struct Channels {
    public enum Buffering {
        case oldest(Int)
        case newest(Int)
        case unbounded
    }

    public enum Completion {
        case finished
        case failure(Error)
    }
}

public final class Channel<Value> {
    private struct ChannelError: Error {
        let wrapper: State
    }

    private struct WriterNode {
        let resumption: Resumption<Void>?
        let value: Value
    }

    private final class State: AtomicReference, Identifiable, Equatable {
        static func == (lhs: Channel<Value>.State, rhs: Channel<Value>.State) -> Bool { lhs.id == rhs.id }

        let completion: Channels.Completion?
        let readers: PersistentQueue<Resumption<Value>>
        let writers: PersistentQueue<WriterNode>

        var id: ObjectIdentifier { .init(self) }

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
            writers = PersistentQueue<WriterNode>(.init(resumption: .none, value: value))
        }
    }

    private let buffering: Channels.Buffering
    private let wrapped: ManagedAtomic<State>

    public init(buffering: Channels.Buffering = .unbounded, _ value: Value? = .none) {
        self.buffering = buffering
        self.wrapped = value == nil ? ManagedAtomic(State()) : ManagedAtomic(State(value!))
    }

    public func cancel(with error: Error = CancellationError()) throws -> Void {
        var localState = wrapped.load(ordering: .sequentiallyConsistent)
        while true {
            try checkStatus(localState)
            let readers = localState.readers
            let writers = localState.writers
            let (success, newLocalState) = wrapped.compareExchange(
                expected: localState,
                desired: .init(completion: .failure(error), readers: .init(), writers: .init()),
                ordering: .relaxed
            )
            if success {
                readers.forEach { $0.resume(throwing: error) }
                writers.forEach { $0.resumption?.resume(throwing: error) }
                break
            } else {
                localState = newLocalState
            }
        }
    }

    public func write() async throws -> Void where Value == Void {
        try await write(())
    }

    /*:
     write a value and block until read
     throws if the channel is completed or if writing the value causes a value to be dropped
     if a blocked writer is dropped, it handles the drop, if the write was non-blocking the current
     writer handles the drop
     */
    public func write(_ value: Value) async throws -> Void {
        var localState = wrapped.load(ordering: .relaxed)
        while true {
            try checkStatus(localState)
            let (dequeued, newReaders) = localState.readers.dequeue()
            switch dequeued {
                case .none:
                    let nextLocalWrapped = try await enqueueForWriting(localState, value)
                    guard nextLocalWrapped != nil else { return }
                    localState = nextLocalWrapped!
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
                    reader.resume(returning: value)
                    return
            }
        }
    }

    public func write() throws -> Void where Value == Void {
        try write(())
    }

    // Non-blocking write
    public func write(_ value: Value) throws -> Void {
        var localState = wrapped.load(ordering: .relaxed)
        while true {
            try checkStatus(localState)
            let (dequeued, newReaders) = localState.readers.dequeue()
            switch dequeued {
                case .none:
                    let nextLocalWrapped = try enqueueAsValue(localState, value)
                    guard nextLocalWrapped != nil else { return }
                    localState = nextLocalWrapped!
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
                    reader.resume(returning: value)
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
                    catch { continue }
                case let .some(writerNode):
                    let (success, newLocalState) = wrapped.compareExchange(
                        expected: localState,
                        desired: .init(readers: localState.readers, writers: newWriters),
                        ordering: .releasing
                    )
                    guard success else { localState = newLocalState; continue }
                    writerNode.resumption?.resume()
                    return writerNode.value
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
                    guard success else { localState = newLocalState; continue }
                    writerNode.resumption?.resume()
                    return writerNode.value
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

    private func enqueueAsValue(_ localState: State, _ value: Value) throws -> State? {
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
                    dropped.resumption?.resume(throwing: ChannelDroppedWriteError())
                    return .none
                }
            case (false, _):
                return newLocalState
        }
    }

    private func enqueueForWriting(_ localState: State, _ value: Value) async throws -> State? {
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
                        ? resumption.resume(throwing: ChannelDroppedValueError(value: dropped.value))
                        : dropped.resumption?.resume(throwing: ChannelDroppedWriteError())
                    case (false, _):
                        resumption.resume(
                            throwing: ChannelError(wrapper: newLocalState)
                        )
                }
            }
            return .none
        } catch {
            guard let error = error as? ChannelError else { throw error }
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
            resumption.resume(throwing: ChannelError(wrapper: newLocalState))
        }
    }
}
