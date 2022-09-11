//
//  AsyncFunc.swift
//  UsingFreeCombine
//
//  Created by Van Simmons on 9/5/22.
//
public struct AsyncFunc<A, B> {
    private let call: (A) async throws -> B
    public init(
        _ call: @escaping (A) async throws -> B
    ) {
        self.call = call
    }
    public func callAsFunction(_ a: A) async throws -> B {
        try await call(a)
    }
}

extension AsyncFunc {
    public func map<C>(
        _ transform: @escaping (B) async throws -> C
    ) -> AsyncFunc<A, C> {
        .init { a in try await transform(call(a)) }
    }

    public func flatMap<C>(
        _ transform: @escaping (B) async throws -> AsyncFunc<A, C>
    ) -> AsyncFunc<A, C> {
        .init { a in try await transform(call(a))(a) }
    }
}

public func zip<A, B, C>(
    _ left: AsyncFunc<A, B>,
    _ right: AsyncFunc<A, C>
) -> AsyncFunc<A, (B, C)> {
    .init { a in
        async let bc = (left(a), right(a))
        return try await bc
    }
}
