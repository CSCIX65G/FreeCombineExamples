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
        .init { resumption, downstream in self(onStartup: resumption) { r in switch r {
            case .success(let a):
                _ = await transform(a)(downstream).result
            case let .failure(error):
                await downstream(.failure(error))
        } } }
    }
}

public extension Publisher {
    func flatMap<T>(
        _ transform: @escaping (Output) async -> Publisher<T>
    ) -> Publisher<T> {
        .init { resumption, downstream in self(onStartup: resumption) { r in switch r {
            case .value(let a):
                return try await transform(a)(flattener(downstream)).value
            case let .completion(value):
                return try await downstream(.completion(value))
        } } }
    }
}

public extension Cancellable {
    func flatMap<T>(
        _ transform: @escaping (Output) async -> Cancellable<T>
    ) -> Cancellable<T> {
        map(transform).join()
    }
}

extension Uncancellable {
    public func flatMap<T>(
        _ transform: @escaping (Output) async -> Uncancellable<T>
    ) -> Uncancellable<T> {
        map(transform).join()
    }
}

extension AsyncFunc {
    public func flatMap<T>(
        _ transform: @escaping (R) async throws -> AsyncFunc<A, T>
    ) -> AsyncFunc<A, T> {
        .init { a in try await transform(call(a))(a) }
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
