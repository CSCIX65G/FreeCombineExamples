//
//  FlatMapError.swift
//  
//
//  Created by Van Simmons on 9/18/22.
//
extension Future {
    func flatMapError(
        _ transform: @escaping (Error) async -> Self
    ) -> Self {
        .init { resumption, downstream in
            self(onStartup: resumption) { r in switch r {
                case .success:
                    await downstream(r)
                case let .failure(error):
                    _ = await transform(error)(downstream).result
            } }
        }
    }
}

public extension Publisher {
    func flatMapError(
        _ transform: @escaping (Swift.Error) async -> Publisher<Output>
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
