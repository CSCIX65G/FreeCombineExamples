//
//  AsyncFunc.swift
//  UsingFreeCombine
//
//  Created by Van Simmons on 9/5/22.
//
public struct AsyncFunc<A, R> {
    let call: (A) async throws -> R
    public init(
        _ call: @escaping (A) async throws -> R
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
    public func callAsFunction(continuation: AsyncStream<R>.Continuation) -> (A) async throws -> Void {
        { value in try await self(continuation: continuation, value: value)}
    }

    public func callAsFunction(continuation: AsyncStream<R>.Continuation) -> AsyncFunc<A, Void> {
        .init(self.callAsFunction(continuation: continuation))
    }
//    public func callAsFunction<State>(channel: Channel<R>, value: A) async throws -> AsyncFold<State, R> {
//        switch try await continuation.yield(call(value)) {
//            case .enqueued: return
//            case .terminated: throw EnqueueError<R>.terminated
//            case let .dropped(r): throw EnqueueError.dropped(r)
//            @unknown default:
//                fatalError("Unimplemented enqueue case")
//        }
//    }
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
