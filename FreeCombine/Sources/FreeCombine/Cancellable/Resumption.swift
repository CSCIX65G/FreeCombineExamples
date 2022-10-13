//
//  Resumption.swift
//  UsingFreeCombine
//
//  Created by Van Simmons on 9/5/22.
//
@preconcurrency import Atomics

public final class Resumption<Output: Sendable>: Sendable {
    private let function: StaticString
    private let file: StaticString
    private let line: UInt

    private let atomicHasResumed = ManagedAtomic<Bool>(false)
    private let continuation: UnsafeContinuation<Output, Swift.Error>

    private var hasResumed: Bool {
        atomicHasResumed.load(ordering: .sequentiallyConsistent)
    }

    private var canResume: Bool {
        let (success, _) = atomicHasResumed.compareExchange(
            expected: false,
            desired: true,
            ordering: .sequentiallyConsistent
        )
        return success
    }

    private var leakFailureString: String {
        "ABORTING DUE TO PREVIOUS RESUMPTION: \(type(of: Self.self)):\(self)  CREATED in \(function) @ \(file): \(line)"
    }
    private var multipleResumeFailureString: String {
        "ABORTING DUE TO PREVIOUS RESUMPTION: \(type(of: Self.self)):\(self)  CREATED in \(function) @ \(file): \(line)"
    }

    public init(
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

    /*:
     [leaks of NIO EventLoopPromises](https://github.com/apple/swift-nio/blob/48916a49afedec69275b70893c773261fdd2cfde/Sources/NIOCore/EventLoopFuture.swift#L431)
     */
    deinit {
        guard hasResumed else {
            assertionFailure(leakFailureString)
            continuation.resume(throwing: LeakError())
            return
        }
    }

    public func resume(returning output: Output) {
        guard canResume else {
            preconditionFailure(multipleResumeFailureString)
        }
        continuation.resume(returning: output)
    }

    public func resume(throwing error: Swift.Error) {
        guard canResume else {
            preconditionFailure(multipleResumeFailureString)
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
