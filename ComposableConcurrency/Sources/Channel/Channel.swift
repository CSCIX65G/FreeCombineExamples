//
//  Channel.swift
//  
//
//  Created by Van Simmons on 11/28/22.
//

import Core
import Atomics
import DequeModule

public final class Channel<Value> {
    private struct ChannelError: Error {
        let wrapper: Wrapper
    }

    private struct WriterNode {
        let resumption: Resumption<Void>?
        let value: Value
    }

    private final class Wrapper: AtomicReference, Identifiable, Equatable {
        static func == (lhs: Channel<Value>.Wrapper, rhs: Channel<Value>.Wrapper) -> Bool { lhs.id == rhs.id }

        let error: Error?
        let readers: PersistentQueue<Resumption<Value>>
        let writers: PersistentQueue<WriterNode>

        var id: ObjectIdentifier { .init(self) }

        init(
            error: Error? = .none,
            readers: PersistentQueue<Resumption<Value>> = .init(),
            writers: PersistentQueue<WriterNode> = .init()
        ) {
            self.error = error
            self.readers = readers
            self.writers = writers
        }

        init(_ value: Value) {
            error = .none
            readers = .init()
            let (_, initialWriters) = PersistentQueue<WriterNode>().enqueue(.init(resumption: .none, value: value))
            writers = initialWriters
        }
    }

    private let wrapped: ManagedAtomic<Wrapper>

    public func cancel(with error: Error = CancellationError()) throws -> Void {
        var localWrapped = wrapped.load(ordering: .sequentiallyConsistent)
        while true {
            guard localWrapped.error == nil else { throw ChannelCancellationFailureError(error: localWrapped.error!) }
            let readers = localWrapped.readers
            let writers = localWrapped.writers
            let (success, newLocalWrapped) = wrapped.compareExchange(
                expected: localWrapped,
                desired: .init(error: error, readers: .init(), writers: .init()),
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

    public init() {
        self.wrapped = ManagedAtomic(Wrapper())
    }

    public init(_ value: Value) {
        self.wrapped = ManagedAtomic(Wrapper(value))
    }

    public func write() async throws -> Void where Value == Void {
        try await write(())
    }

    public func write(_ value: Value) async throws -> Void {
        var localWrapped = wrapped.load(ordering: .acquiring)
        while true {
            guard localWrapped.error == nil else { throw localWrapped.error! }
            let (dequeued, newReaders) = localWrapped.readers.dequeue()
            switch dequeued {
                case .none:
                    guard let nextLocalWrapped = try await blockForWriting(localWrapped, value) else {
                        return
                    }
                    localWrapped = nextLocalWrapped
                case let .some(reader):
                    let (success, newLocalWrapped) = wrapped.compareExchange(
                        expected: localWrapped,
                        desired: .init(readers: newReaders, writers: localWrapped.writers),
                        ordering: .releasing
                    )
                    guard success else { localWrapped = newLocalWrapped; continue }
                    reader.resume(returning: value)
                    return
            }
        }
    }

    private func blockForWriting(_ localWrapped: Wrapper, _ value: Value) async throws -> Wrapper? {
        do {
            let _: Void = try await pause { resumption in
                let (dropped, writers) = localWrapped.writers.enqueue(.init(resumption: resumption, value: value))
                let (success, newLocalWrapped) = wrapped.compareExchange(
                    expected: localWrapped,
                    desired: Wrapper(readers: localWrapped.readers, writers: writers),
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
            guard localWrapped.error == nil else { throw localWrapped.error! }
            let (dequeued, newWriters) = localWrapped.writers.dequeue()
            switch dequeued {
                case .none:
                    if !blocking { throw FailedReadError() }
                    do { return try await blockForReading(&localWrapped) }
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

    private func blockForReading(_ localWrapped: inout Channel<Value>.Wrapper) async throws -> Value {
        let value: Value = try await pause { resumption in
            let (_, readers) = localWrapped.readers.enqueue(resumption)
            let newVar = Wrapper(readers: readers, writers: localWrapped.writers)
            let (success, newLocalWrapped) = wrapped.compareExchange(
                expected: localWrapped,
                desired: newVar,
                ordering: .sequentiallyConsistent
            )
            if success {
                return
            }
            else {
                localWrapped = newLocalWrapped
                resumption.resume(throwing: ChannelError(wrapper: newLocalWrapped))
            }
        }
        return value
    }
}
