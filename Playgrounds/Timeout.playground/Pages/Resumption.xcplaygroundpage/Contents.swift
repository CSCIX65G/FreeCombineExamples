//: [Previous](@previous)
/*:
 [Swift Evolution Proposal 300: Continuations](https://github.com/apple/swift-evolution/blob/main/proposals/0300-continuation.md)

     After invoking withUnsafeContinuation, exactly one resume method must be called exactly-once on every execution path through the program. Unsafe*Continuation is an unsafe interface, so it is undefined behavior if a resume method is invoked on the same continuation more than once. The task remains in the suspended state until it is resumed; if the continuation is discarded and never resumed, then the task will be left suspended until the process ends, leaking any resources it holds. Wrappers can provide checking for these misuses of continuations, and the library will provide one such wrapper, discussed below.

 NB There's a data race on resuming Continuations.  Unlike Task, this race produces UB.  Also, if you leak one of these, it's _really_ bad.  Therefore we'd like the following to be true...

 # Resumption of a suspended task is _failable_

 1. Like `isCancelled`, Resumption status is _not_ publicly visible
 2. Multiple resumptions are not UB and simply checked and logged, they are failure
 3. Leaking a suspended task is a _hard_ failure because there is no way to have a `throw`ing deinit.  In fact _all_ conccurency-related leaks should be treated similarly.

  [leaks of NIO EventLoopPromises](https://github.com/apple/swift-nio/blob/48916a49afedec69275b70893c773261fdd2cfde/Sources/NIOCore/EventLoopFuture.swift#L431)

 */
import Atomics

@available(iOS 13, *)
public final class Resumption<Output: Sendable>: @unchecked Sendable {
    public enum Error: Swift.Error {
        case leaked
        case alreadyResumed
    }

    private let atomicHasResumed = ManagedAtomic<Bool>(false)
    private let continuation: UnsafeContinuation<Output, Swift.Error>

    private var hasResumed: Bool {
        atomicHasResumed.load(ordering: .sequentiallyConsistent)
    }

    private var canResume: Bool {
        atomicHasResumed.compareExchange(
            expected: false,
            desired: true,
            ordering: .sequentiallyConsistent
        ).0
    }

    public init(continuation: UnsafeContinuation<Output, Swift.Error>) {
        self.continuation = continuation
    }

    deinit {
        guard hasResumed else {
            assertionFailure("ABORTING DUE TO LEAKED \(type(of: Self.self)):\(self)")
            continuation.resume(throwing: Error.leaked)
            return
        }
    }

    public func resume(returning output: Output) {
        guard canResume else {
            preconditionFailure("ABORTING DUE TO PREVIOUS RESUMPTION: \(type(of: Self.self)):\(self)")
        }
        continuation.resume(returning: output)
    }

    public func resume(throwing error: Swift.Error) {
        guard canResume else {
            preconditionFailure("ABORTING DUE TO PREVIOUS RESUMPTION: \(type(of: Self.self)):\(self)")
        }
        continuation.resume(throwing: error)
    }
}

extension Resumption where Output == Void {
    public func resume() {
        resume(returning: ())
    }
}

@available(iOS 13, *)
public func withResumption<Output>(
    _ resumingWith: (Resumption<Output>) -> Void
) async throws -> Output {
    try await withUnsafeThrowingContinuation { continuation in
        resumingWith(.init(continuation: continuation))
    }
}

//: [Next](@next)
