//
//  AsyncFunc.swift
//  UsingFreeCombine
//
//  Created by Van Simmons on 9/5/22.
//


public struct AsyncFunc<A, B> {
    let call: (A) async throws -> B
    public init(
        _ call: @escaping (A) async throws -> B
    ) {
        self.call = call
    }
    public func callAsFunction(_ a: A) async throws -> B {
        try await call(a)
    }
}

public extension AsyncFunc {
    func map<C>(
        _ f: @escaping (B) async -> C
    ) -> AsyncFunc<A, C> {
        .init { a in try await f(self(a)) }
    }

    func flatMap<C>(
        _ f: @escaping (B) async -> AsyncFunc<A, C>
    ) -> AsyncFunc<A, C> {
        .init { a in try await f(self(a))(a) }
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

// (A) -> B
// (A, B) -> A?
// (A) -> (A, ((A) -> B)?)

public extension AsyncFunc {
//    func trampoline(
//        over: @escaping (A, B) async -> A?
//    ) -> AsyncFunc<A, (A, Self?)> {
//        .init { a in
//            guard let next = try await over(a, self(a))
//        }
//    }
}
