//
//  UnfailingResumption.swift
//  
//
//  Created by Van Simmons on 9/17/22.
//
import Atomics

public final class UnfailingResumption<Output: Sendable>: @unchecked Sendable {
    typealias Status = Resumptions.Status
    private let function: StaticString
    private let file: StaticString
    private let line: UInt

    private let atomicStatus = ManagedAtomic<Status>(.waiting)
    private let continuation: UnsafeContinuation<Output, Never>

    private var status: Status {
        atomicStatus.load(ordering: .sequentiallyConsistent)
    }

    private var leakFailureString: String {
        "ABORTING DUE TO LEAKED RESUMPTION: \(type(of: Self.self)):\(self)  CREATED in \(function) @ \(file): \(line)"
    }

    private var multipleResumeFailureString: String {
        "ABORTING DUE TO PREVIOUS RESUMPTION: \(type(of: Self.self)):\(self)  CREATED in \(function) @ \(file): \(line)"
    }

    public init(
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
        guard status == .resumed else {
            assertionFailure(leakFailureString)
            return
        }
    }

    private func set(status newStatus: Status) -> Result<Void, Swift.Error> {
        Result.success(()).set(atomic: self.atomicStatus, from: .waiting, to: newStatus)
    }

    @Sendable public func tryResume(returning output: Output) throws -> Void {
        switch set(status: .resumed) {
            case .success: return continuation.resume(returning: output)
            case .failure(let error): throw error
        }
    }

    @Sendable public func resume(returning output: Output) -> Void {
        do { try tryResume(returning: output) }
        catch { preconditionFailure(multipleResumeFailureString) }
    }
}

public extension UnfailingResumption where Output == Void {
    @inlinable @Sendable func tryResume() throws -> Void {
        try tryResume(returning: ())
    }
    @inlinable @Sendable func resume() -> Void {
        resume(returning: ())
    }
}

public func unfailingPause<Output>(
    function: StaticString = #function,
    file: StaticString = #file,
    line: UInt = #line,
    for: Output.Type = Output.self,
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
