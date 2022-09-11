//
//  Cancellable.swift
//  UsingFreeCombine
//
//  Created by Van Simmons on 9/5/22.
//
@preconcurrency import Atomics

public final class Cancellable<Output: Sendable>: Sendable {
    public enum Error: Swift.Error {
        case cancelled
        case internalError
    }
    private let task: Task<Output, Swift.Error>
    private let deallocGuard: ManagedAtomic<Bool>

    public init(
        operation: @escaping @Sendable () async throws -> Output
    ) {
        let atomic = ManagedAtomic<Bool>(false)
        self.deallocGuard = atomic
        self.task = .init {
            do {
                let retValue = try await operation()
                atomic.store(true, ordering: .sequentiallyConsistent)
                guard !Task.isCancelled else { throw Error.cancelled }
                return retValue
            }
            catch {
                atomic.store(true, ordering: .sequentiallyConsistent)
                throw error
            }
        }
    }

    public init<Inner>(
        operation: @escaping @Sendable () async throws -> Output
    ) where Output == Cancellable<Inner> {
        let atomic = ManagedAtomic<Bool>(false)
        self.deallocGuard = atomic
        self.task = .init {
            do {
                let retValue = try await operation()
                atomic.store(true, ordering: .sequentiallyConsistent)
                guard !Task.isCancelled else {
                    retValue.cancel()
                    throw Error.cancelled
                }
                return retValue
            }
            catch {
                atomic.store(true, ordering: .sequentiallyConsistent)
                throw error
            }
        }
    }

    public var isCancelled: Bool { task.isCancelled }
    public var isCompleting: Bool { deallocGuard.load(ordering: .sequentiallyConsistent) }

    @Sendable public func cancel() {
        guard !isCompleting else { return }
        task.cancel()
    }

    public var value: Output {
        get async throws { try await task.value }
    }
    public var result: Result<Output, Swift.Error> {
        get async { await task.result }
    }

    public var canDeallocate: Bool { isCompleting || isCancelled }

    deinit {
        guard canDeallocate else {
            assertionFailure("ABORTING DUE TO LEAKED \(type(of: Self.self))")
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
                    guard !Task.isCancelled else { throw Error.cancelled }
                    let transformed = await transform(value)
                    guard !Task.isCancelled else { throw Error.cancelled }
                    return transformed
                },
                onCancel: { self.cancel() }
            )
        }
    }

    public func join<T>() -> Cancellable<T> where Output == Cancellable<T> {
        .init {
            try await withTaskCancellationHandler(
                operation: {
                    let inner = try await self.value
                    guard !Task.isCancelled else {
                        inner.cancel()
                        throw Error.cancelled
                    }
                    let value = try await inner.value
                    guard !Task.isCancelled else {
                        throw Error.cancelled
                    }
                    return value
                },
                onCancel: { self.cancel() }
            )
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
