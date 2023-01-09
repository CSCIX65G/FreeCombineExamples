//
//  File.swift
//  
//
//  Created by Van Simmons on 1/8/23.
//

extension AsyncFunc {
    public func flatMap<T>(
        _ transform: @escaping (R) async throws -> AsyncFunc<A, T>
    ) -> AsyncFunc<A, T> {
        .init { a in try await transform(call(a))(a) }
    }
}
