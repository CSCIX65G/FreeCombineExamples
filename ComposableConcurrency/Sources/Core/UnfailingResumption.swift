//
//  UnfailingResumption.swift
//  
//
//  Created by Van Simmons on 2/12/23.
//
import SendableAtomics

public final class UnfailingResumption<Output>: Sendable {
    private typealias Status = Resumptions.Status

    private let function: StaticString
    private let file: StaticString
    private let line: UInt
    private let deinitBehavior: Uncancellables.LeakBehavior
    
    private let status: @Sendable (Status) throws -> Void = Once<Status>().set
    private let continuation: UnsafeContinuation<Output, Never>

    private var leakFailureString: String {
        "LEAKED \(type(of: Self.self)):\(self). CREATED in \(function) @ \(file): \(line)"
    }

    @Sendable public init(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        deinitBehavior: Uncancellables.LeakBehavior = .assert,
        continuation: UnsafeContinuation<Output, Never>
    ) {
        self.function = function
        self.file = file
        self.line = line
        self.deinitBehavior = deinitBehavior
        self.continuation = continuation
    }

    deinit {
        do { try status(.resumed) }
        catch { return }
        switch deinitBehavior {
            case .assert: // Taking the NIO approach...
                assertionFailure("ASSERTION FAILURE: \(self.leakFailureString)") // Taking the NIO approach
            case .fatal:  // Taking the Chuck Norris approach
                fatalError("FATAL ERROR: \(self.leakFailureString)")
        }
    }

    @Sendable public func resume(returning output: Output) throws -> Void {
        try status(.resumed)
        continuation.resume(returning: output)
    }
}

public extension UnfailingResumption where Output == Void {
    @Sendable func resume() throws -> Void {
        try resume(returning: ())
    }
}

@Sendable public func unfailingPause<Output>(
    function: StaticString = #function,
    file: StaticString = #file,
    line: UInt = #line,
    deinitBehavior: Uncancellables.LeakBehavior = .assert,
    for: Output.Type = Output.self,
    _ resumingWith: (UnfailingResumption<Output>) -> Void
) async -> Output {
    await withUnsafeContinuation { continuation in
        resumingWith(.init(function: function, file: file, line: line, deinitBehavior: deinitBehavior, continuation: continuation))
    }
}
