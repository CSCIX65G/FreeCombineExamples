//
//  File.swift
//  
//
//  Created by Van Simmons on 1/8/23.
//
import Core

extension AsyncFunc {
    public func map<C>(
        _ transform: @escaping (R) async throws -> C
    ) -> AsyncFunc<A, C> {
        .init { a in
            let b = try await call(a)
            try Task.checkCancellation()
            return try await transform(b)
        }
    }
}
