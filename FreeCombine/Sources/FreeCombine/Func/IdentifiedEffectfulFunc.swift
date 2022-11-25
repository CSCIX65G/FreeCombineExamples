//
//  IdentifiedStreamedFunc.swift
//  
//
//  Created by Van Simmons on 11/25/22.
//
class IdentifiedEffectfulFunc<A, R>: Identifiable {
    let f: (A) async throws -> R
    private(set) var id: ObjectIdentifier! = .none

    init(f: @escaping (A) async throws -> R) {
        self.f = f
        self.id = ObjectIdentifier(self)
    }

    func callAsFunction(continuation: AsyncStream<(ObjectIdentifier, R)>.Continuation, value: A) async throws -> Void {
        switch try await continuation.yield((id, f(value))) {
            case .enqueued: return
            case .terminated: throw EnqueueError<R>.terminated
            case let .dropped(r): throw EnqueueError.dropped(r)
            @unknown default:
                fatalError("Unimplemented enqueue case")
        }
    }
    func callAsFunction(continuation: AsyncStream<(ObjectIdentifier, R)>.Continuation) -> (A) async throws -> Void {
        { value in try await self(continuation: continuation, value: value)}
    }
    func callAsFunction(continuation: AsyncStream<(ObjectIdentifier, R)>.Continuation) -> AsyncFunc<A, Void> {
        .init(self.callAsFunction(continuation: continuation))
    }
}
