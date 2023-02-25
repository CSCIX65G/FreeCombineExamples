//
//  AsyncFunc.swift
//  UsingFreeCombine
//
//  Created by Van Simmons on 9/5/22.
//
//  Copyright 2022, ComputeCycles, LLC
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//
import Core

public struct AsyncFunc<A: Sendable, R: Sendable>: Sendable {
    public let call: @Sendable (A) async throws -> R
    public init(
        _ call: @Sendable @escaping (A) async throws -> R
    ) {
        self.call = call
    }
    public func callAsFunction(_ a: A) async throws -> R {
        try await call(a)
    }
}

extension AsyncFunc {
    public func callAsFunction(continuation: AsyncStream<R>.Continuation, value: A) async throws -> Void {
        switch try await continuation.yield(call(value)) {
            case .enqueued: return
            case .terminated: throw EnqueueError<R>.terminated
            case let .dropped(r): throw EnqueueError.dropped(r)
            @unknown default:
                fatalError("Unimplemented enqueue case")
        }
    }

    @Sendable public func stream(into continuation: AsyncStream<R>.Continuation) -> @Sendable (A) async throws -> Void {
        { value in try await self(continuation: continuation, value: value) }
    }

    public func stream(into continuation: AsyncStream<R>.Continuation) -> AsyncFunc<A, Void> {
        .init(stream(into: continuation))
    }
}

public extension AsyncFunc {
    func map<C>(
        _ f: @escaping (R) async -> C
    ) -> AsyncFunc<A, C> {
        .init { a in try await f(self(a)) }
    }

    func flatMap<C>(
        _ f: @escaping (R) async -> AsyncFunc<A, C>
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
