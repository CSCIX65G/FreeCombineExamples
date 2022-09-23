//
//  UnfailingResumption.swift
//  
//
//  Created by Van Simmons on 9/17/22.
//
import Atomics

public final class UnfailingResumption<Output: Sendable>: @unchecked Sendable {
    private let function: StaticString
    private let file: StaticString
    private let line: UInt

    private let atomicHasResumed = ManagedAtomic<Bool>(false)
    private let continuation: UnsafeContinuation<Output, Never>

    init(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        continuation: UnsafeContinuation<Output, Never>
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
        guard atomicHasResumed.load(ordering: .sequentiallyConsistent) else {
            preconditionFailure(
                "ABORTING DUE TO LEAKED \(type(of: Self.self)):\(self)  CREATED in \(function) @ \(file): \(line)"
            )
        }
    }

    // Note this has a sideffect on first call and must be private
    private var canResume: Bool {
        let (success, _) = atomicHasResumed.compareExchange(
            expected: false,
            desired: true,
            ordering: .sequentiallyConsistent
        )
        return success
    }

    public func resume(returning output: Output) {
        guard canResume else {
            preconditionFailure(
                "ABORTING DUE TO LEAKED \(type(of: Self.self)):\(self)  CREATED in \(function) @ \(file): \(line)"
            )
        }
        continuation.resume(returning: output)
    }
}

extension UnfailingResumption where Output == Void {
    public func resume() {
        resume(returning: ())
    }
}

public func withUnfailingResumption<Output>(
    function: StaticString = #function,
    file: StaticString = #file,
    line: UInt = #line,
    _ resumingWith: (UnfailingResumption<Output>) -> Void
) async -> Output {
    await withUnsafeContinuation { continuation in
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
