//
//  Channel.swift
//
//
//  Created by Van Simmons on 9/5/22.
//
public struct Channel<Element: Sendable> {
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

    @discardableResult
    @Sendable public func yield(_ value: Element) -> AsyncStream<Element>.Continuation.YieldResult {
        continuation.yield(value)
    }

    @discardableResult
    @Sendable public func send(_ value: Element) -> AsyncStream<Element>.Continuation.YieldResult {
        yield(value)
    }

    @Sendable public func finish() {
        continuation.finish()
    }
}

extension Channel where Element == Void {
    @discardableResult
    @Sendable public func yield() -> AsyncStream<Element>.Continuation.YieldResult {
        continuation.yield(())
    }
    @discardableResult
    @Sendable public func send() -> AsyncStream<Element>.Continuation.YieldResult {
        yield(())
    }
}

extension Channel {
    public func fold<State>(
        onStartup: Resumption<Void>,
        into reducer: Folder<State, Element>
    ) -> AsyncFold<State, Element> {
        .init(onStartup: onStartup, channel: self, folder: reducer)
    }
}
