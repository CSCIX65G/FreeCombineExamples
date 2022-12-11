//
//  File.swift
//  
//
//  Created by Van Simmons on 12/10/22.
//

import Foundation

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
