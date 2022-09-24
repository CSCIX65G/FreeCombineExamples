//
//  Channel.swift
//
//
//  Created by Van Simmons on 9/5/22.
//
public struct Channel<Element: Sendable> {
    typealias Error = Channels.Error
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
}

public enum Channels {
    public enum Error: Swift.Error, Sendable, CaseIterable {
        case cancelled
        case completed
        case internalError
        case enqueueError
    }
}

public extension Channel {
    @discardableResult
    @Sendable func yield(_ value: Element) -> AsyncStream<Element>.Continuation.YieldResult {
        continuation.yield(value)
    }

    @discardableResult
    @Sendable func send(_ value: Element) -> AsyncStream<Element>.Continuation.YieldResult {
        yield(value)
    }

    @Sendable func finish() {
        continuation.finish()
    }
}

public extension Channel where Element == Void {
    @discardableResult
    @Sendable func yield() -> AsyncStream<Element>.Continuation.YieldResult {
        continuation.yield(())
    }
    @discardableResult
    @Sendable func send() -> AsyncStream<Element>.Continuation.YieldResult {
        yield(())
    }
}
