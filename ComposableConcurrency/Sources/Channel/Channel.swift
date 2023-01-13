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
            let (_, initialWriters) = PersistentQueue<WriterNode>().enqueue(.init(resumption: .none, value: value))
            writers = initialWriters
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

    public func cancel(with error: Error = CancellationError()) throws -> Void {
        var localWrapped = wrapped.load(ordering: .sequentiallyConsistent)
        while true {
            guard localWrapped.completion == nil else { throw ChannelCompleteError(completion: localWrapped.completion!) }
            let readers = localWrapped.readers
            let writers = localWrapped.writers
            let (success, newLocalWrapped) = wrapped.compareExchange(
                expected: localWrapped,
                desired: .init(completion: .failure(error), readers: .init(), writers: .init()),
                ordering: .sequentiallyConsistent
            )
            if success {
                readers.forEach { $0.resume(throwing: error) }
                writers.forEach { $0.resumption?.resume(throwing: error) }
                break
            } else {
                localWrapped = newLocalWrapped
            }
        }
    }

    public func write() async throws -> Void where Value == Void {
        try await write(())
    }

    public func write(blocking: Bool = true, _ value: Value) async throws -> Void {
        var localWrapped = wrapped.load(ordering: .relaxed)
        while true {
            guard localWrapped.completion == nil else { throw ChannelCompleteError(completion: localWrapped.completion!) }
            let (dequeued, newReaders) = localWrapped.readers.dequeue()
            switch dequeued {
                case .none:
                    let nextLocalWrapped = blocking
                    ? try await enqueueForWriting(localWrapped, value)
                    : try await enqueueAsValue(localWrapped, value)
                    guard nextLocalWrapped != nil else { return }
                    localWrapped = nextLocalWrapped!
                case let .some(reader):
                    let (success, newLocalWrapped) = wrapped.compareExchange(
                        expected: localWrapped,
                        desired: .init(readers: newReaders, writers: localWrapped.writers),
                        ordering: .relaxed
                    )
                    guard success else {
                        localWrapped = newLocalWrapped
                        continue
                    }
                    reader.resume(returning: value)
                    return
            }
        }
    }

    private func enqueueAsValue(_ localWrapped: State, _ value: Value) async throws -> State? {
        let (dropped, writers) = localWrapped.writers.enqueue(.init(resumption: .none, value: value))
        let (success, newLocalWrapped) = wrapped.compareExchange(
            expected: localWrapped,
            desired: State(readers: localWrapped.readers, writers: writers),
            ordering: .relaxed
        )
        dropped?.resumption?.resume(throwing: ChannelError(wrapper: newLocalWrapped))
        return success ? .none : newLocalWrapped
    }

    private func enqueueForWriting(_ localWrapped: State, _ value: Value) async throws -> State? {
        do {
            let _: Void = try await pause { resumption in
                let (dropped, writers) = localWrapped.writers.enqueue(.init(resumption: resumption, value: value))
                let (success, newLocalWrapped) = wrapped.compareExchange(
                    expected: localWrapped,
                    desired: State(readers: localWrapped.readers, writers: writers),
                    ordering: .relaxed
                )
                switch (success, dropped) {
                    case (true, .none):
                        return
                    case let (true, .some(dropped)):
                        dropped.resumption?.resume(throwing: ChannelError(wrapper: newLocalWrapped))
                        return
                    case (false, _):
                        resumption.resume(throwing: ChannelError(wrapper: newLocalWrapped))
                }
            }
            return .none
        } catch {
            guard let error = error as? ChannelError else { throw error }
            return error.wrapper
        }
    }

    public func read(blocking: Bool = true) async throws -> Value {
        var localWrapped = wrapped.load(ordering: .acquiring)
        while true {
            guard localWrapped.completion == nil else { throw ChannelCompleteError(completion: localWrapped.completion!) }
            let (dequeued, newWriters) = localWrapped.writers.dequeue()
            switch dequeued {
                case .none:
                    if !blocking { throw FailedReadError() }
                    do { return try await enqueueForReading(&localWrapped) }
                    catch { continue }
                case let .some(writerNode):
                    let (success, newLocalWrapped) = wrapped.compareExchange(
                        expected: localWrapped,
                        desired: .init(readers: localWrapped.readers, writers: newWriters),
                        ordering: .releasing
                    )
                    guard success else { localWrapped = newLocalWrapped; continue }
                    writerNode.resumption?.resume()
                    return writerNode.value
            }
        }
    }

    private func enqueueForReading(_ localWrapped: inout Channel<Value>.State) async throws -> Value {
        try await pause { resumption in
            let (_, readers) = localWrapped.readers.enqueue(resumption)
            let newVar = State(readers: readers, writers: localWrapped.writers)
            let (success, newLocalWrapped) = wrapped.compareExchange(
                expected: localWrapped,
                desired: newVar,
                ordering: .sequentiallyConsistent
            )
            guard !success else { return }
            localWrapped = newLocalWrapped
            resumption.resume(throwing: ChannelError(wrapper: newLocalWrapped))
        }
    }
}
