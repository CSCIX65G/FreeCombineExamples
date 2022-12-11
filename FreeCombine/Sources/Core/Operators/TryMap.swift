//
//  File.swift
//  
//
//  Created by Van Simmons on 12/10/22.
//
public extension AsyncContinuation {
    func tryMap<T>(
        _ transform: @escaping (Output) async throws -> T
    ) -> AsyncContinuation<T, Return> {
        .init { resumption, downstream in
            self(onStartup: resumption) { a in
                try await downstream(transform(a))
            }
        }
    }
}
