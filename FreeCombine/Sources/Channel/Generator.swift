//
//  Generator.swift
//
//
//  Created by Van Simmons on 12/2/22.
//
//import Atomics
//import FreeCombine
//
//public enum Generators {
//    enum Status: UInt8, Equatable, AtomicValue {
//        case waiting
//        case succeeded
//        case failed
//    }
//}
//
//public final class Generator<Value> {
//    private struct GeneratorError: Error {
//        let wrapper: Wrapper
//    }
//    private final class Wrapper: AtomicReference, Identifiable, Hashable, Equatable {
//        let value: Result<Value?, Error>
//        let writer: Resumption<Void>
//
//        init(
//            _ value: Value?,
//            writer: Resumption<Void>
//        ) {
//            self.value = .success(value)
//            self.writer = writer
//        }
//
//        init(
//            result: Result<Value?, Error>,
//            writer: Resumption<Void>
//        ) {
//            self.value = result
//            self.writer = writer
//        }
//
//        static func == (
//            lhs: Generator<Value>.Wrapper,
//            rhs: Generator<Value>.Wrapper
//        ) -> Bool { lhs.id == rhs.id }
//        var id: ObjectIdentifier { .init(self) }
//        func hash(into hasher: inout Hasher) { hasher.combine(self) }
//    }
//
//    private let wrapped: ManagedAtomic<Wrapper>
//
//    public func cancel(with error: Error = CancellationError()) throws -> Void {
//        var localWrapped = wrapped.load(ordering: .sequentiallyConsistent)
//        while true {
//            _ = try localWrapped.value.get()
//            let readers = localWrapped.readers
//            let writers = localWrapped.writers
//            let (success, newLocalWrapped) = wrapped.compareExchange(
//                expected: localWrapped,
//                desired: .init(result: .failure(error), readers: [], writers: []),
//                ordering: .sequentiallyConsistent
//            )
//            if success {
//                readers.forEach { $0.resume(throwing: error) }
//                writers.forEach { $0.resume(throwing: error) }
//            } else {
//                localWrapped = newLocalWrapped
//            }
//        }
//    }
//
//    public init(_ value: Value? = .none) {
//        self.wrapped = ManagedAtomic(Wrapper(value))
//    }
//
//    public func write() async throws -> Void where Value == Void {
//        try await write(())
//    }
//
//    public func write(_ value: Value) async throws -> Void {
//        var localWrapped = wrapped.load(ordering: .sequentiallyConsistent)
//        while true {
//            switch try localWrapped.value.get() {
//                case .some:
//                    guard let newLocalWrapped = try await blockForWriting(localWrapped, .none) else { return }
//                    localWrapped = newLocalWrapped
//                case .none:
//                    guard let newLocalWrapped = try await dispatchReaderOrBlockForWriting(localWrapped, value) else { return }
//                    localWrapped = newLocalWrapped
//            }
//        }
//    }
//
//    public func read() async throws -> Value {
//        var localWrapped = wrapped.load(ordering: .sequentiallyConsistent)
//        while true {
//            switch try localWrapped.value.get() {
//                case let .some(value):
//                    do { return try await dispatchWriter(localWrapped, value) }
//                    catch {
//                        guard let error = error as? Generator else { throw error }
//                        localWrapped = error.wrapper
//                        continue
//                    }
//                case .none:
//                    do { return try await blockForReading(&localWrapped) }
//                    catch {
//                        continue
//                    }
//            }
//        }
//    }
//
//    private func blockForWriting(_ localWrapped: Wrapper, _ value: Value?) async throws -> Wrapper? {
//        do {
//            let _: Void = try await pause { resumption in
//                var writers = localWrapped.writers
//                writers.insert(resumption)
//                let newVar = Wrapper(value, readers: localWrapped.readers, writers: writers)
//                let (success, newLocalWrapped) = wrapped.compareExchange(
//                    expected: localWrapped,
//                    desired: newVar,
//                    ordering: .sequentiallyConsistent
//                )
//                if success { return }
//                else { resumption.resume(throwing: Generator(wrapper: newLocalWrapped)) }
//            }
//            return .none
//        } catch {
//            guard let error = error as? Generator else { throw error }
//            return error.wrapper
//        }
//    }
//
//    private func dispatchReaderOrBlockForWriting(_ localWrapped: Wrapper, _ value: Value) async throws -> Wrapper? {
//        var readers = localWrapped.readers
//        if !readers.isEmpty {
//            let reader = readers.removeFirst()
//            let newVar = Wrapper(.none, readers: readers, writers: localWrapped.writers)
//            let (success, newLocalWrapped) = wrapped.compareExchange(
//                expected: localWrapped,
//                desired: newVar,
//                ordering: .sequentiallyConsistent
//            )
//            if success {
//                reader.resume(returning: value)
//                return .none
//            } else {
//                return newLocalWrapped
//            }
//        } else {
//            return try await blockForWriting(localWrapped, value)
//        }
//    }
//
//    private func blockForReading(_ localWrapped: inout Generator<Value>.Wrapper) async throws -> Value {
//        let value: Value = try await pause { resumption in
//            var readers = localWrapped.readers
//            readers.insert(resumption)
//            let newVar = Wrapper(.none, readers: readers, writers: localWrapped.writers)
//            let (success, newLocalWrapped) = wrapped.compareExchange(
//                expected: localWrapped,
//                desired: newVar,
//                ordering: .sequentiallyConsistent
//            )
//            if success {
//                return
//            }
//            else {
//                localWrapped = newLocalWrapped
//                resumption.resume(throwing: Generator(wrapper: newLocalWrapped))
//            }
//        }
//        return value
//    }
//
//    private func dispatchWriter(_ localWrapped: Wrapper, _ value: Value) async throws -> Value {
//        var writers = localWrapped.writers
//        let writer: Resumption<Void>? = writers.isEmpty ? .none : writers.removeFirst()
//        let newVar = Wrapper(.none, readers: localWrapped.readers, writers: writers)
//        let (success, newLocalWrapped) = wrapped.compareExchange(
//            expected: localWrapped,
//            desired: newVar,
//            ordering: .sequentiallyConsistent
//        )
//        if success {
//            writer?.resume()
//            return value
//        } else {
//            throw Generator(wrapper: newLocalWrapped)
//        }
//    }
//}
