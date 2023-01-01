//
//  Channel.swift
//  
//
//  Created by Van Simmons on 11/28/22.
//

import Atomics
import Core
@_implementationOnly import DequeModule

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

        let value: AsyncResult<Value?, Error>
        let readers: PersistentQueue<Resumption<Value>>
        let writers: PersistentQueue<Resumption<Void>>

        var id: ObjectIdentifier { .init(self) }

        init(
            _ value: Value?,
            readers: PersistentQueue<Resumption<Value>> = .init(),
            writers: PersistentQueue<Resumption<Void>> = .init()
        ) {
            self.value = .success(value)
            self.readers = readers
            self.writers = writers
        }

        init(
            result: AsyncResult<Value?, Error>,
            readers: PersistentQueue<Resumption<Value>> = .init(),
            writers: PersistentQueue<Resumption<Void>> = .init()
        ) {
            self.value = result
            self.readers = readers
            self.writers = writers
        }
    }

    private let wrapped: ManagedAtomic<Wrapper>

    public func cancel(with error: Error = CancellationError()) throws -> Void {
        var localWrapped = wrapped.load(ordering: .sequentiallyConsistent)
        while true {
            _ = try localWrapped.value.get()
            let readers = localWrapped.readers
            let writers = localWrapped.writers
            let (success, newLocalWrapped) = wrapped.compareExchange(
                expected: localWrapped,
                desired: .init(result: .failure(error), readers: .init(), writers: .init()),
                ordering: .sequentiallyConsistent
            )
            if success {
                readers.forEach { $0.resume(throwing: error) }
                writers.forEach { $0.resume(throwing: error) }
                break
            } else {
                localWrapped = newLocalWrapped
            }
        }
    }

    public init(_ value: Value? = .none) {
        self.wrapped = ManagedAtomic(Wrapper(value))
    }

    public func write() async throws -> Void where Value == Void {
        try await write(())
    }

    public func write(_ value: Value) async throws -> Void {
        var localWrapped = wrapped.load(ordering: .sequentiallyConsistent)
        while true {
            switch try localWrapped.value.get() {
                case .some:
                    guard let newLocalWrapped = try await blockForWriting(localWrapped, .none) else { return }
                    localWrapped = newLocalWrapped
                case .none:
                    guard let newLocalWrapped = try await dispatchReaderOrBlockForWriting(localWrapped, value) else { return }
                    localWrapped = newLocalWrapped
            }
        }
    }

    /// Non-blocking, failable read
    public func read(blocking: Bool = true) async throws -> Value {
        var localWrapped = wrapped.load(ordering: .sequentiallyConsistent)
        while true {
            switch try localWrapped.value.get() {
                case let .some(value):
                    do { return try dispatchWriter(localWrapped, value) }
                    catch {
                        guard let error = error as? ChannelError else { throw error }
                        localWrapped = error.wrapper
                        continue
                    }
                case .none:
                    if !blocking { throw FailedReadError() }
                    do { return try await blockForReading(&localWrapped) }
                    catch { continue }
            }
        }
    }

    private func blockForWriting(_ localWrapped: Wrapper, _ value: Value?) async throws -> Wrapper? {
        do {
            let _: Void = try await pause { resumption in
                let (_, writers) = localWrapped.writers.enqueue(resumption)
                let (success, newLocalWrapped) = wrapped.compareExchange(
                    expected: localWrapped,
                    desired: Wrapper(value, readers: localWrapped.readers, writers: writers),
                    ordering: .sequentiallyConsistent
                )
                if success { return }
                else { resumption.resume(throwing: ChannelError(wrapper: newLocalWrapped)) }
            }
            return .none
        } catch {
            guard let error = error as? ChannelError else { throw error }
            return error.wrapper
        }
    }

    private func dispatchReaderOrBlockForWriting(_ localWrapped: Wrapper, _ value: Value) async throws -> Wrapper? {
        let (dequeuedReader, readers) = localWrapped.readers.dequeue()
        if let reader = dequeuedReader {
            let newVar = Wrapper(.none, readers: readers, writers: localWrapped.writers)
            let (success, newLocalWrapped) = wrapped.compareExchange(
                expected: localWrapped,
                desired: newVar,
                ordering: .sequentiallyConsistent
            )
            if success {
                reader.resume(returning: value)
                return .none
            } else {
                return newLocalWrapped
            }
        } else {
            return try await blockForWriting(localWrapped, value)
        }
    }

    private func blockForReading(_ localWrapped: inout Channel<Value>.Wrapper) async throws -> Value {
        let value: Value = try await pause { resumption in
            let (_, readers) = localWrapped.readers.enqueue(resumption)
            let newVar = Wrapper(.none, readers: readers, writers: localWrapped.writers)
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

    private func dispatchWriter(_ localWrapped: Wrapper, _ value: Value) throws -> Value {
        let (writer, writers) = localWrapped.writers.dequeue()
        let newVar = Wrapper(.none, readers: localWrapped.readers, writers: writers)
        let (success, newLocalWrapped) = wrapped.compareExchange(
            expected: localWrapped,
            desired: newVar,
            ordering: .sequentiallyConsistent
        )
        if success {
            writer?.resume()
            return value
        } else {
            throw ChannelError(wrapper: newLocalWrapped)
        }
    }
}
