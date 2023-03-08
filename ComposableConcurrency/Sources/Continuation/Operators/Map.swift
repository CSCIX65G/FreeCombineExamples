//
//  File.swift
//  
//
//  Created by Van Simmons on 1/8/23.
//
import Core

public extension AsyncContinuation {
    func map<T: Sendable>(
        _ transform: @Sendable @escaping (Output) async -> T
    ) -> AsyncContinuation<T, Return> {
        .init { resumption, downstream in
            self(onStartup: resumption) { a in
                let t = await transform(a)
                try Task.checkCancellation()
                return try await downstream(t)
            }
        }
    }
}
