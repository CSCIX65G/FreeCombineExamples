//
//  Channel.swift
//
//
//  Created by Van Simmons on 9/5/22.
//
public struct Channel<Element: Sendable>: Sendable {
    let continuation: AsyncStream<Element>.Continuation
    let stream: AsyncStream<Element>

    public init(
        _: Element.Type = Element.self,
        buffering: AsyncStream<Element>.Continuation.BufferingPolicy = .bufferingOldest(1)
    ) {
        var localContinuation: AsyncStream<Element>.Continuation!
        stream = .init(bufferingPolicy: buffering) { localContinuation = $0 }
        continuation = localContinuation
    }

    public init<Other>(
        _: Element.Type = Element.self,
        buffering: AsyncStream<Other>.Continuation.BufferingPolicy = .bufferingOldest(1)
    ) {
        var localContinuation: AsyncStream<Element>.Continuation!
        stream = .init(bufferingPolicy: Self.convertBuffering(buffering)) { localContinuation = $0 }
        continuation = localContinuation
    }

    private static func convertBuffering<Other>(
        _ other: AsyncStream<Other>.Continuation.BufferingPolicy
    ) -> AsyncStream<Element>.Continuation.BufferingPolicy {
        switch other {
            case .unbounded:
                return .unbounded
            case let .bufferingOldest(value):
                return .bufferingOldest(value)
            case let .bufferingNewest(value):
                return .bufferingNewest(value)
            @unknown default:
                fatalError("Unknown buffering value")
        }
    }
}

public extension AsyncStream.Continuation {
    @Sendable func tryYield(_ value: Element) throws -> Void {
        switch yield(value) {
            case .enqueued: return
            case .dropped(let element): throw EnqueueError.dropped(element)
            case .terminated: throw EnqueueError<Element>.terminated
            @unknown default: fatalError("Unknown error")
        }
    }
}

extension Channel: AsyncSequence {
    public typealias AsyncIterator = AsyncStream<Element>.AsyncIterator
    public func makeAsyncIterator() -> AsyncStream<Element>.AsyncIterator {
        stream.makeAsyncIterator()
    }
}

public extension Channel {
    @Sendable func tryYield(_ value: Element) throws -> Void {
        switch continuation.yield(value) {
            case .enqueued: return
            case .dropped(let element): throw EnqueueError.dropped(element)
            case .terminated: throw EnqueueError<Element>.terminated
            @unknown default: fatalError("Unknown error")
        }
    }

    @Sendable func yield(_ value: Element) -> AsyncStream<Element>.Continuation.YieldResult {
        continuation.yield(value)
    }

    @Sendable func finish() {
        continuation.finish()
    }
}

public extension Channel where Element == Void {
    @inlinable @Sendable func tryYield() throws -> Void {
        try tryYield(())
    }
    @inlinable @Sendable func yield() -> AsyncStream<Element>.Continuation.YieldResult {
        yield(())
    }
}
