//
//  Resumption.swift
//  UsingFreeCombine
//
//  Created by Van Simmons on 9/5/22.
//
import Atomics

enum Resumptions {
    enum Status: UInt8, RawRepresentable, Equatable, Sendable {
        case waiting
        case resumed
    }
}

public final class Resumption<Output: Sendable>: @unchecked Sendable {
    typealias Status = Resumptions.Status
    private let function: StaticString
    private let file: StaticString
    private let line: UInt

    private let atomicStatus = ManagedAtomic<UInt8>(Status.waiting.rawValue)
    private let continuation: UnsafeContinuation<Output, Swift.Error>

    private var status: Status {
        Status(rawValue: atomicStatus.load(ordering: .sequentiallyConsistent))!
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
        guard status == .resumed else {
            assertionFailure(leakFailureString)
            continuation.resume(throwing: LeakError())
            return
        }
    }

    private func set(status newStatus: Status) -> Result<Void, Swift.Error> {
        Result.success(()).set(atomic: self.atomicStatus, from: .waiting, to: newStatus)
    }

    public func resume(returning output: Output) -> Void {
        do { try tryResume(returning: output) }
        catch { preconditionFailure(multipleResumeFailureString) }
    }

    public func tryResume(returning output: Output) throws -> Void {
        switch set(status: .resumed) {
            case .success: return continuation.resume(returning: output)
            case .failure(let error): throw error
        }
    }

    public func resume(throwing error: Swift.Error) -> Void {
        do { try tryResume(throwing: error) }
        catch { preconditionFailure(multipleResumeFailureString) }
    }

    public func tryResume(throwing error: Swift.Error) throws -> Void {
        switch set(status: .resumed) {
            case .success: return continuation.resume(throwing: error)
            case .failure(let error): throw error
        }
    }
}

extension Resumption where Output == Void {
    public func resume() -> Void {
        resume(returning: ())
    }

    public func tryResume() throws -> Void {
        try tryResume(returning: ())
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
