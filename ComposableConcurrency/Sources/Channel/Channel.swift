//
//  Channel.swift
//  
//
//  Created by Van Simmons on 11/28/22.
//

import Core
import Atomics
import DequeModule

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

    public init(buffering: Channels.Buffering = .unbounded) {
        self.buffering = buffering
        self.wrapped = ManagedAtomic(State())
    }

    public init(buffering: Channels.Buffering = .unbounded, _ value: Value) {
        self.buffering = buffering
        self.wrapped = ManagedAtomic(State(value))
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

    public func cancel(with error: Error = CancellationError()) throws -> Void {
        var localState = wrapped.load(ordering: .sequentiallyConsistent)
        while true {
            guard localState.completion == nil else { throw ChannelCompleteError(completion: localState.completion!) }
            let readers = localState.readers
            let writers = localState.writers
            let (success, newLocalState) = wrapped.compareExchange(
                expected: localState,
                desired: .init(completion: .failure(error), readers: .init(), writers: .init()),
                ordering: .sequentiallyConsistent
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

    public func write(blocking: Bool = true) async throws -> Void where Value == Void {
        try await write(blocking: blocking, ())
    }

    public func write(blocking: Bool = true, _ value: Value) async throws -> Void {
        var localState = wrapped.load(ordering: .relaxed)
        while true {
            try checkStatus(localState)
            let (dequeued, newReaders) = localState.readers.dequeue()
            switch dequeued {
                case .none:
                    let nextLocalWrapped = blocking
                    ? try await enqueueForWriting(localState, value)
                    : try await enqueueAsValue(localState, value)
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

    private func enqueueAsValue(_ localState: State, _ value: Value) async throws -> State? {
        let (dropped, writers) = localState.writers.enqueue(.init(resumption: .none, value: value))
        let (success, newLocalState) = wrapped.compareExchange(
            expected: localState,
            desired: State(readers: localState.readers, writers: writers),
            ordering: .relaxed
        )
        dropped?.resumption?.resume(throwing: ChannelError(wrapper: newLocalState))
        return success ? .none : newLocalState
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
                        return
                    case let (true, .some(dropped)):
                        dropped.resumption?.resume(throwing: ChannelError(wrapper: newLocalState))
                        return
                    case (false, _):
                        resumption.resume(throwing: ChannelError(wrapper: newLocalState))
                }
            }
            return .none
        } catch {
            guard let error = error as? ChannelError else { throw error }
            return error.wrapper
        }
    }

    public func read(blocking: Bool = true) async throws -> Value {
        var localState = wrapped.load(ordering: .acquiring)
        while true {
            try checkStatus(localState)
            let (dequeued, newWriters) = localState.writers.dequeue()
            switch dequeued {
                case .none:
                    if !blocking { throw FailedReadError() }
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
