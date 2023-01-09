//
//  WriteChannel.swift
//
//
//  Created by Van Simmons on 11/28/22.
//  FIXME: This is woefully non-performant and needs to adapt a real MPMC fifo algorithm
//  But all the ones I can find are C++ as macros.  sigh.
//

import Core
import Atomics
import DequeModule

public final class WriteChannel<Value> {
    private struct Error: Swift.Error {
        let wrapper: Wrapper
    }
    private final class Wrapper: AtomicReference, Identifiable, Hashable, Equatable {
        let value: AsyncResult<Value?, Swift.Error>
        let writers: Deque<Resumption<Void>>

        init() {
            self.value = .success(.none)
            self.writers = []
        }

        init(
            result: AsyncResult<Value?, Swift.Error>,
            writers: Deque<Resumption<Void>> = []
        ) {
            self.value = result
            self.writers = writers
        }

        static func == (lhs: WriteChannel<Value>.Wrapper, rhs: WriteChannel<Value>.Wrapper) -> Bool { lhs.id == rhs.id }
        var id: ObjectIdentifier { .init(self) }
        func hash(into hasher: inout Hasher) { hasher.combine(self) }
    }

    private let wrapped: ManagedAtomic<Wrapper>

    public func cancel(with error: Swift.Error = CancellationError()) throws -> Void {
        var localWrapped = wrapped.load(ordering: .sequentiallyConsistent)
        while true {
            _ = try localWrapped.value.get()
            let writers = localWrapped.writers
            let (success, newLocalWrapped) = wrapped.compareExchange(
                expected: localWrapped,
                desired: .init(result: .failure(error), writers: []),
                ordering: .sequentiallyConsistent
            )
            if success {
                writers.forEach { $0.resume(throwing: error) }
            } else {
                localWrapped = newLocalWrapped
            }
        }
    }

    public init() {
        self.wrapped = ManagedAtomic(Wrapper())
    }

    public func write() async throws -> Void where Value == Void {
        try await write(())
    }

    public func write(_ value: Value) async throws -> Void {
        var localWrapped = wrapped.load(ordering: .sequentiallyConsistent)
        while true {
            guard let newLocalWrapped = try await blockForWriting(localWrapped, value) else { return }
            localWrapped = newLocalWrapped
        }
    }

    public func read() throws -> Value? {
        while true {
            var localWrapped = wrapped.load(ordering: .sequentiallyConsistent)
            switch try localWrapped.value.get() {
                case let .some(value):
                    do {
                        return try dispatchWriter(localWrapped, value)
                    }
                    catch {
                        guard let error = error as? Error else { throw error }
                        localWrapped = error.wrapper
                        continue
                    }
                case .none:
                    return .none
            }
        }
    }

    private func blockForWriting(_ localWrapped: Wrapper, _ value: Value?) async throws -> Wrapper? {
        do {
            let _: Void = try await pause { resumption in
                var writers = localWrapped.writers
                writers.append(resumption)
                let newWrapper = Wrapper(result: .success(value), writers: writers)
                let (success, newLocalWrapped) = wrapped.compareExchange(
                    expected: localWrapped,
                    desired: newWrapper,
                    ordering: .sequentiallyConsistent
                )
                if success {
                    return
                }
                else {
                    resumption.resume(throwing: Error(wrapper: newLocalWrapped))
                }
            }
            return .none
        } catch {
            guard let error = error as? Error else { throw error }
            return error.wrapper
        }
    }

    private func dispatchWriter(_ localWrapped: Wrapper, _ value: Value) throws -> Value {
        var writers = localWrapped.writers
        let writer: Resumption<Void>? = writers.isEmpty ? .none : writers.removeFirst()
        let newVar = Wrapper(result: .success(.none), writers: writers)
        let (success, newLocalWrapped) = wrapped.compareExchange(
            expected: localWrapped,
            desired: newVar,
            ordering: .sequentiallyConsistent
        )
        if success {
            writer?.resume()
            return value
        } else {
            throw Error(wrapper: newLocalWrapped)
        }
    }
}
