//
//  StreamedFunc.swift
//  
//
//  Created by Van Simmons on 11/25/22.
//
public func consume<A, R>(
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

extension Channel {
    func consume<A>(
        _ f: @escaping (A) async throws -> Element
    ) -> (A) async throws -> Void {
        self.continuation.consume(f)
    }
    func consume<A>(
        _ f: @escaping (A) async throws -> Element
    ) -> AsyncFunc<A, Void> {
        self.continuation.consume(f)
    }
}

extension AsyncStream.Continuation {
    func consume<A>(
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

    func consume<A>(
        _ f: @escaping (A) async throws -> Element
    ) -> AsyncFunc<A, Void> {
        .init(self.consume(f))
    }
}

extension IdentifiedAsyncFunc {
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
    func callAsFunction(channel: Channel<(ObjectIdentifier, R)>, value: A) async throws -> Void {
        try await self(continuation: channel.continuation, value: value)
    }
    func callAsFunction(channel: Channel<(ObjectIdentifier, R)>) -> (A) async throws -> Void {
        { value in try await self(continuation: channel.continuation, value: value)}
    }
    func callAsFunction(channel: Channel<(ObjectIdentifier, R)>) -> AsyncFunc<A, Void> {
        .init(self.callAsFunction(continuation: channel.continuation))
    }
}

