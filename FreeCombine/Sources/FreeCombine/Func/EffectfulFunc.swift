//
//  StreamedFunc.swift
//  
//
//  Created by Van Simmons on 11/25/22.
//
public func effectfulFunc<A, R>(
    _ f: @escaping (A) async throws -> R
) -> (AsyncStream<R>.Continuation) -> (A) async throws -> Void {
    { continuation in { a in switch try await continuation.yield(f(a)) {
        case .enqueued: return
        case .terminated: throw EnqueueError<R>.terminated
        case let .dropped(r): throw EnqueueError.dropped(r)
        @unknown default:
            fatalError("Unimplemented enqueue case")
    } } }
}

extension AsyncStream.Continuation {
//    func asyncContinuation<R>(_ type: R.Type = R.self) -> AsyncContinuation<Element, R> {
//
//    }
}

public struct EffectfulFunc<A, R> {
    let f: (A) async throws -> R
    public init(f: @escaping (A) async throws -> R) {
        self.f = f
    }

    public func callAsFunction(continuation: AsyncStream<R>.Continuation, value: A) async throws -> Void {
        switch try await continuation.yield(f(value)) {
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
}
