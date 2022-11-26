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
    func effectfulFunc<A>(
        _ f: @escaping (A) async throws -> Element
    ) -> (A) async throws -> Void {
        { a in switch try await self.yield(f(a)) {
            case .enqueued: return
            case .terminated: throw EnqueueError<A>.terminated
            case let .dropped(r): throw EnqueueError.dropped(r)
            @unknown default:
                fatalError("Unimplemented enqueue case")
        } }
    }
}
