//
//  MVar.swift
//  
//
//  Created by Van Simmons on 11/28/22.
//

import Atomics

public final class MVar<Value> {
    public struct WrapperError: Error { }

    final class Wrapper: AtomicReference, Identifiable, Hashable, Equatable {
        static func == (lhs: MVar<Value>.Wrapper, rhs: MVar<Value>.Wrapper) -> Bool {
            lhs.id == rhs.id
        }

        let value: Result<Value?, Error>
        let readers: Set<Resumption<Value>>
        let writers: Set<Resumption<Void>>
        var id: ObjectIdentifier { .init(self) }

        init(
            _ value: Value?,
            readers: Set<Resumption<Value>> = [],
            writers: Set<Resumption<Void>> = []
        ) {
            self.value = .success(value)
            self.readers = readers
            self.writers = writers
        }

        init(
            result: Result<Value?, Error>,
            readers: Set<Resumption<Value>> = [],
            writers: Set<Resumption<Void>> = []
        ) {
            self.value = result
            self.readers = readers
            self.writers = writers
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(self)
        }
    }

    let wrapped: ManagedAtomic<Wrapper>

    public func cancel(with error: Error = CancellationError()) throws -> Void {
        var localVar = wrapped.load(ordering: .sequentiallyConsistent)
        while true {
            _ = try localVar.value.get()
            let readers = localVar.readers
            let writers = localVar.writers
            let (success, newLocalVar) = wrapped.compareExchange(
                expected: localVar,
                desired: .init(result: .failure(error), readers: [], writers: []),
                ordering: .sequentiallyConsistent
            )
            if success {
                readers.forEach { $0.resume(throwing: error) }
                writers.forEach { $0.resume(throwing: error) }
            } else {
                localVar = newLocalVar
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
        var localVar = wrapped.load(ordering: .sequentiallyConsistent)
        while true {
            switch try localVar.value.get() {
                case .some:
                    do {
                        let _: Void = try await pause { resumption in
                            var writers = localVar.writers
                            writers.insert(resumption)
                            let newVar = Wrapper(.none, readers: localVar.readers, writers: writers)
                            let (success, newLocalVar) = wrapped.compareExchange(
                                expected: localVar,
                                desired: newVar,
                                ordering: .sequentiallyConsistent
                            )
                            if success { return }
                            else {
                                localVar = newLocalVar
                                resumption.resume(throwing: WrapperError())
                            }
                        }
                        return
                    } catch {
                    }
                case .none:
                    var readers = localVar.readers
                    if !readers.isEmpty {
                        let reader = readers.removeFirst()
                        let newVar = Wrapper(.none, readers: readers, writers: localVar.writers)
                        let (success, newLocalVar) = wrapped.compareExchange(
                            expected: localVar,
                            desired: newVar,
                            ordering: .sequentiallyConsistent
                        )
                        if success {
                            reader.resume(returning: value)
                            return
                        } else {
                            localVar = newLocalVar
                        }
                    } else {
                        do {
                            let _: Void = try await pause { resumption in
                                var writers = localVar.writers
                                writers.insert(resumption)
                                let newVar = Wrapper(value, readers: localVar.readers, writers: writers)
                                let (success, newLocalVar) = wrapped.compareExchange(
                                    expected: localVar,
                                    desired: newVar,
                                    ordering: .sequentiallyConsistent
                                )
                                if success {
                                    return
                                }
                                else {
                                    localVar = newLocalVar
                                    resumption.resume(throwing: WrapperError())
                                }
                            }
                            return
                        } catch {
                        }
                    }
            }
        }
    }

    func read() async throws -> Value {
        var localVar = wrapped.load(ordering: .sequentiallyConsistent)
        while true {
            switch try localVar.value.get() {
                case let .some(value):
                    var writers = localVar.writers
                    let writer: Resumption<Void>? = writers.isEmpty ? .none : writers.removeFirst()
                    let newVar = Wrapper(.none, readers: localVar.readers, writers: writers)
                    let (success, newLocalVar) = wrapped.compareExchange(
                        expected: localVar,
                        desired: newVar,
                        ordering: .sequentiallyConsistent
                    )
                    if success {
                        writer?.resume()
                        return value
                    } else {
                        localVar = newLocalVar
                    }
                case .none:
                    do {
                        let value: Value = try await pause { resumption in
                            var readers = localVar.readers
                            readers.insert(resumption)
                            let newVar = Wrapper(.none, readers: readers, writers: localVar.writers)
                            let (success, newLocalVar) = wrapped.compareExchange(
                                expected: localVar,
                                desired: newVar,
                                ordering: .sequentiallyConsistent
                            )
                            if success {
                                return
                            }
                            else {
                                localVar = newLocalVar
                                resumption.resume(throwing: WrapperError())
                            }
                        }
                        return value
                    } catch {
                    }
            }
        }
    }
}
