//
//  Map.swift
//
//
//  Created by Van Simmons on 9/18/22.
//
extension Future {
    public func map<T>(
        _ transform: @escaping (Output) async -> T
    ) -> Future<T> {
        .init { resumption, downstream in
            self(onStartup: resumption) { r in
                switch r {
                    case .success(let a):
                        await downstream(.success(transform(a)))
                    case let .failure(error):
                        await downstream(.failure(error))
                }
            }
        }
    }
}

public extension AsyncContinuation {
    func map<T>(
        _ transform: @escaping (Output) async -> T
    ) -> AsyncContinuation<T, Return> {
        .init { resumption, downstream in
            self(onStartup: resumption) { a in
                try await downstream(transform(a))
            }
        }
    }
}

public extension Publisher {
    func map<B>(
        _ transform: @escaping (Output) async -> B
    ) -> Publisher<B> {
        .init { resumption, downstream in
            self(onStartup: resumption) { r in switch r {
                case .value(let a):
                    return try await downstream(.value(transform(a)))
                case let .completion(value):
                    return try await downstream(.completion(value))
            } }
        }
    }
}

public extension Cancellable {
    func map<T>(_ transform: @escaping (Output) async -> T) -> Cancellable<T> {
        .init {
            try await withTaskCancellationHandler(
                operation: {
                    let value = try await self.value
                    guard !Cancellables.isCancelled else { throw Error.cancelled }
                    let transformed = await transform(value)
                    return transformed
                },
                onCancel: { try? self.cancel() }
            )
        }
    }
}

extension Uncancellable {
    public func map<T>(
        _ transform: @escaping (Output) async -> T
    ) -> Uncancellable<T> {
        .init { await transform(self.value) }
    }
}

extension AsyncFunc {
    public func map<C>(
        _ transform: @escaping (B) async throws -> C
    ) -> AsyncFunc<A, C> {
        .init { a in try await transform(call(a)) }
    }
}
