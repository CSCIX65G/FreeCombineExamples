//
//  Cancellable.swift
//  UsingFreeCombine
//
//  Created by Van Simmons on 9/5/22.
//
@preconcurrency import Atomics

public enum Cancellables {
    public enum Error: Swift.Error, Sendable {
        case cancelled
        case alreadyCompleted
        case alreadyCancelled
        case alreadyFailed
        case internalInconsistency
    }

    public enum Status: UInt8, Sendable, RawRepresentable, Equatable {
        case running
        case finished
        case cancelled

        static func get(
            atomic: ManagedAtomic<UInt8>
        ) -> Status {
            let value = atomic.load(ordering: .sequentiallyConsistent)
            return .init(rawValue: value)!
        }

        @discardableResult
        static func set(
            atomic: ManagedAtomic<UInt8>,
            to newStatus: Status
        ) throws -> Status {
            let (success, original) = atomic.compareExchange(
                expected: Status.running.rawValue,
                desired: newStatus.rawValue,
                ordering: .sequentiallyConsistent
            )
            guard success else {
                switch original {
                    case Status.finished.rawValue: throw Error.alreadyCompleted
                    case Status.cancelled.rawValue: throw Error.alreadyCancelled
                    default: throw Error.internalInconsistency
                }
            }
            return newStatus
        }
    }
}

public final class Cancellable<Output: Sendable>: Sendable {
    public typealias Error = Cancellables.Error
    public typealias Status = Cancellables.Status

    private let task: Task<Output, Swift.Error>
    private let atomicStatus = ManagedAtomic<UInt8>(Status.running.rawValue)

    public let function: StaticString
    public let file: StaticString
    public let line: UInt

    public init(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        operation: @escaping @Sendable () async throws -> Output
    ) {
        self.function = function
        self.file = file
        self.line = line
        let atomic = atomicStatus
        self.task = .init {
            var retValue: Output!
            do {
                retValue = try await operation()
            } catch {
                do { try Status.set(atomic: atomic, to: .finished) }
                catch { throw Error.cancelled }
                throw error
            }
            do { try Status.set(atomic: atomic, to: .finished) }
            catch {  throw Error.cancelled }
            return retValue
        }
    }

    public init<Inner>(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        operation: @escaping @Sendable () async throws -> Output
    ) where Output == Cancellable<Inner> {
        self.function = function
        self.file = file
        self.line = line
        let atomic = atomicStatus
        self.task = .init {
            var retValue: Output!
            do {
                retValue = try await operation()
                guard Status.get(atomic: atomic) != .cancelled else {
                    try retValue.cancel()
                    throw Error.cancelled
                }
            } catch {
                do { try Status.set(atomic: atomic, to: .finished) }
                catch {  throw Error.cancelled }
                throw error
            }
            do { try Status.set(atomic: atomic, to: .finished) }
            catch { throw Error.cancelled }
            return retValue
        }
    }

    public var isCancelled: Bool { task.isCancelled }
    public var status: Status { Status.get(atomic: atomicStatus) }

    @Sendable public func cancel() throws {
        try Status.set(atomic: atomicStatus, to: .cancelled)
        task.cancel()
    }

    public var value: Output {
        get async throws { try await task.value }
    }
    public var result: Result<Output, Swift.Error> {
        get async { await task.result }
    }

    deinit {
        guard status != .running else {
            assertionFailure(
                "ABORTING DUE TO LEAKED \(type(of: Self.self)) CREATED in \(function) @ \(file): \(line)"
            )
            task.cancel()
            return
        }
    }
}

extension Cancellable {
    public func map<T>(_ transform: @escaping (Output) async -> T) -> Cancellable<T> {
        .init {
            try await withTaskCancellationHandler(
                operation: {
                    let value = try await self.value
                    guard self.status != .cancelled else { throw Error.cancelled }
                    let transformed = await transform(value)
                    try Status.set(atomic: self.atomicStatus, to: .finished)
                    return transformed
                },
                onCancel: { try? self.cancel() }
            )
        }
    }

    public func join<T>() -> Cancellable<T> where Output == Cancellable<T> {
        .init {
            let inner = try await self.value
            guard self.status != .cancelled else {
                try? inner.cancel()
                throw Error.cancelled
            }
            let value = try await inner.value
            try Status.set(atomic: self.atomicStatus, to: .finished)
            return value
        }
    }

    public func flatMap<T>(
        _ transform: @escaping (Output) async -> Cancellable<T>
    ) -> Cancellable<T> {
        map(transform).join()
    }
}

extension Cancellable {
    public var future: Future<Output> {
        .init { resumption, downstream in
            .init {
                resumption.resume()
                await downstream(self.result)
            }
        }
    }
}
