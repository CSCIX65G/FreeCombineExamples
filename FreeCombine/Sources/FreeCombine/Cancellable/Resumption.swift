//
//  Resumption.swift
//  UsingFreeCombine
//
//  Created by Van Simmons on 9/5/22.
//
@preconcurrency import Atomics

public final class Resumption<Output: Sendable>: Sendable {
    public enum Error: Swift.Error {
        case leaked
        case alreadyResumed
    }

    private let deallocGuard = ManagedAtomic<Bool>(false)
    private let continuation: UnsafeContinuation<Output, Swift.Error>

    public let function: StaticString
    public let file: StaticString
    public let line: UInt

    init(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        continuation: UnsafeContinuation<Output, Swift.Error>
    ) {
        self.function = function
        self.file = file
        self.line = line
        self.continuation = continuation
    }

    public var canDeallocate: Bool {
        deallocGuard.load(ordering: .sequentiallyConsistent)
    }

    /*:
     [leaks of NIO EventLoopPromises](https://github.com/apple/swift-nio/blob/48916a49afedec69275b70893c773261fdd2cfde/Sources/NIOCore/EventLoopFuture.swift#L431)
     */
    deinit {
        guard canDeallocate else {
            assertionFailure(
                "ABORTING DUE TO LEAKED \(type(of: Self.self)):\(self)  CREATED in \(function) @ \(file): \(line)"
            )
            continuation.resume(throwing: Error.leaked)
            return
        }
    }

    // Note this has a sideffect on first call and must be private
    private var canResume: Bool {
        let (success, _) = deallocGuard.compareExchange(
            expected: false,
            desired: true,
            ordering: .sequentiallyConsistent
        )
        return success
    }

    public func resume(returning output: Output) {
        guard canResume else {
            preconditionFailure(
                "\(type(of: Self.self)) FAILED. ALREADY RESUMED \(type(of: Self.self)):\(self)"
            )
        }
        continuation.resume(returning: output)
    }

    public func resume(throwing error: Swift.Error) {
        guard canResume else {
            preconditionFailure(
                "\(type(of: Self.self)) FAILED. ALREADY RESUMED \(type(of: Self.self)):\(self)"
            )
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
    function: StaticString = #function,
    file: StaticString = #file,
    line: UInt = #line,
    _ resumingWith: (Resumption<Output>) -> Void
) async throws -> Output {
    try await withUnsafeThrowingContinuation { continuation in
        resumingWith(
            .init(
                function: function,
                file: file,
                line: line,
                continuation: continuation
            )
        )
    }
}
