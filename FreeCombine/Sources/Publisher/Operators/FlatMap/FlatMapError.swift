//
//  File.swift
//  
//
//  Created by Van Simmons on 12/10/22.
//
import Core

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
