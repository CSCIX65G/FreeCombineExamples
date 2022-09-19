//
//  FlatMap.swift
//  
//
//  Created by Van Simmons on 9/18/22.
//
extension Future {
    func flatMap<T>(
        _ transform: @escaping (Output) async -> Future<T>
    ) -> Future<T> {
        .init { resumption, downstream in
            self(onStartup: resumption) { r in switch r {
                case .success(let a):
                    _ = await transform(a)(downstream).result
                case let .failure(error):
                    await downstream(.failure(error))
            } }
        }
    }
}

public extension AsyncContinuation {
    func flatMap<T>(
        _ transform: @escaping (Output) async -> AsyncContinuation<T, Return>
    ) -> AsyncContinuation<T, Return> {
        .init { resumption, downstream in
            self(onStartup: resumption) { a in
                try await transform(a)(downstream).value
            }
        }
    }
}

extension AsyncFunc {
    public func flatMap<C>(
        _ transform: @escaping (B) async throws -> AsyncFunc<A, C>
    ) -> AsyncFunc<A, C> {
        .init { a in try await transform(call(a))(a) }
    }
}
