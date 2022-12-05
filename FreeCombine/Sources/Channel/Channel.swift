//
//  Channel.swift
//  
//
//  Created by Van Simmons on 11/28/22.
//  FIXME: This is woefully non-performant and needs to adapt a real MPMC algorithm
//  But all the ones I can find are C++ as macros.  sigh.
//

import Atomics
import Core
import DequeModule

public final class Channel<Value> {
    private struct ChannelError: Error {
        let wrapper: Wrapper
    }
    private final class Wrapper: AtomicReference, Identifiable, Hashable, Equatable {
        let value: AsyncResult<Value?, Error>
        let readers: Deque<Resumption<Value>>
        let writers: Deque<Resumption<Void>>

        init(
            _ value: Value?,
            readers: Deque<Resumption<Value>> = [],
            writers: Deque<Resumption<Void>> = []
        ) {
            self.value = .success(value)
            self.readers = readers
            self.writers = writers
        }

        init(
            result: AsyncResult<Value?, Error>,
            readers: Deque<Resumption<Value>> = [],
            writers: Deque<Resumption<Void>> = []
        ) {
            self.value = result
            self.readers = readers
            self.writers = writers
        }

        static func == (lhs: Channel<Value>.Wrapper, rhs: Channel<Value>.Wrapper) -> Bool { lhs.id == rhs.id }
        var id: ObjectIdentifier { .init(self) }
        func hash(into hasher: inout Hasher) { hasher.combine(self) }
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
                desired: .init(result: .failure(error), readers: [], writers: []),
                ordering: .sequentiallyConsistent
            )
            if success {
                readers.forEach { $0.resume(throwing: error) }
                writers.forEach { $0.resume(throwing: error) }
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

    public func read() async throws -> Value {
        var localWrapped = wrapped.load(ordering: .sequentiallyConsistent)
        while true {
            switch try localWrapped.value.get() {
                case let .some(value):
                    do { return try await dispatchWriter(localWrapped, value) }
                    catch {
                        guard let error = error as? ChannelError else { throw error }
                        localWrapped = error.wrapper
                        continue
                    }
                case .none:
                    do { return try await blockForReading(&localWrapped) }
                    catch {
                        continue
                    }
            }
        }
    }

    private func blockForWriting(_ localWrapped: Wrapper, _ value: Value?) async throws -> Wrapper? {
        do {
            let _: Void = try await pause { resumption in
                var writers = localWrapped.writers
                writers.append(resumption)
                let newVar = Wrapper(value, readers: localWrapped.readers, writers: writers)
                let (success, newLocalWrapped) = wrapped.compareExchange(
                    expected: localWrapped,
                    desired: newVar,
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
        var readers = localWrapped.readers
        if !readers.isEmpty {
            let reader = readers.removeFirst()
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
            var readers = localWrapped.readers
            readers.append(resumption)
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

    private func dispatchWriter(_ localWrapped: Wrapper, _ value: Value) async throws -> Value {
        var writers = localWrapped.writers
        let writer: Resumption<Void>? = writers.isEmpty ? .none : writers.removeFirst()
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
