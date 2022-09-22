//
//  TryFlatMapError.swift
//  
//
//  Created by Van Simmons on 9/18/22.
//
extension Future {
    func tryFlatMapError(
        _ transform: @escaping (Error) async throws -> Self
    ) -> Self {
        .init { resumption, downstream in
            self(onStartup: resumption) { r in switch r {
                case .success:
                    await downstream(r)
                case let .failure(tryError):
                    do {  _ = try await transform(tryError)(downstream).result }
                    catch { await downstream(.failure(error)) }
            } }
        }
    }
}

public extension Publisher {
    func tryFlatMapError(
        _ transform: @escaping (Swift.Error) async throws -> Publisher<Output>
    ) -> Publisher<Output> {
        .init { resumption, downstream in
            self(onStartup: resumption) { r in switch r {
                case .value(let a):
                    return try await downstream(.value(a))
                case .completion(.failure(let e)):
                    return try await transform(e)(flattener(downstream)).value
                case .completion(.finished):
                    return try await downstream(.completion(.finished))
            } }
        }
    }
}
