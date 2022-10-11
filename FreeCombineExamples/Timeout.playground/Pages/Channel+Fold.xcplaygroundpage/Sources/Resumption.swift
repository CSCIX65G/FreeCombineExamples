import Atomics

public final class Resumption<Output: Sendable>: @unchecked Sendable {
    public enum Error: Swift.Error {
        case leaked
        case alreadyResumed
    }

    private let atomicHasResumed = ManagedAtomic<Bool>(false)
    private let continuation: UnsafeContinuation<Output, Swift.Error>

    init(continuation: UnsafeContinuation<Output, Swift.Error>) {
        self.continuation = continuation
    }

    public var hasResumed: Bool {
        atomicHasResumed.load(ordering: .sequentiallyConsistent)
    }

    /*:
     [leaks of NIO EventLoopPromises](https://github.com/apple/swift-nio/blob/48916a49afedec69275b70893c773261fdd2cfde/Sources/NIOCore/EventLoopFuture.swift#L431)
     */
    deinit {
        guard hasResumed else {
            assertionFailure("ABORTING DUE TO LEAKED \(type(of: Self.self)):\(self)")
            continuation.resume(throwing: Error.leaked)
            return
        }
    }

    // Note this has a sideffect on first call and must be private
    private var canResume: Bool {
        atomicHasResumed.compareExchange(
            expected: false,
            desired: true,
            ordering: .sequentiallyConsistent
        ).0
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

public func withResumption<Output>(
    _ resumingWith: (Resumption<Output>) -> Void
) async throws -> Output {
    try await withUnsafeThrowingContinuation { continuation in
        resumingWith(.init(continuation: continuation))
    }
}
