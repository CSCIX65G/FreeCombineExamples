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
                let t = await transform(a)
                guard !Cancellables.isCancelled else { throw CancellationError() }
                return try await downstream(t)
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
                    let b = await transform(a)
                    guard !Cancellables.isCancelled else { throw CancellationError() }
                    return try await downstream(.value(b))
                case let .completion(value):
                    return try await downstream(.completion(value))
            } }
        }
    }
}

public extension Cancellable {
    func map<T>(
        _ transform: @escaping (Output) async -> T
    ) -> Cancellable<T> {
        .init {
            let value = try await self.value
            guard !Cancellables.isCancelled else { throw CancellationError() }
            return await transform(value)
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
        .init { a in
            let b = try await call(a)
            guard !Cancellables.isCancelled else { throw CancellationError() }
            return try await transform(b)
        }
    }
}
