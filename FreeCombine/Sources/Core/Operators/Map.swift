//
//  File.swift
//  
//
//  Created by Van Simmons on 12/10/22.
//
public extension Cancellable {
    func map<T>(
        _ transform: @escaping (Output) async -> T
    ) -> Cancellable<T> {
        .init {
            let value = try await self.value
            try Cancellables.checkCancellation()
            return await transform(value)
        }
    }
}

extension Uncancellable {
    public func map<T>(
        _ transform: @escaping (Output) async -> T
    ) -> Uncancellable<T> {
        .init { await transform(self.value) }
    }
}

public extension AsyncContinuation {
    func map<T>(
        _ transform: @escaping (Output) async -> T
    ) -> AsyncContinuation<T, Return> {
        .init { resumption, downstream in
            self(onStartup: resumption) { a in
                let t = await transform(a)
                try Cancellables.checkCancellation()
                return try await downstream(t)
            }
        }
    }
}

extension AsyncFunc {
    public func map<C>(
        _ transform: @escaping (R) async throws -> C
    ) -> AsyncFunc<A, C> {
        .init { a in
            let b = try await call(a)
            try Cancellables.checkCancellation()
            return try await transform(b)
        }
    }
}
