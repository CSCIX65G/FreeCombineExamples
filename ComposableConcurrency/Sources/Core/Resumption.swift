//
//  Resumption.swift
//
//  Created by Van Simmons on 9/5/22.
//
import Atomics
import SendableAtomics

enum Resumptions {
    enum Status: UInt8, AtomicValue, Equatable, Sendable {
        case resumed
    }
}

public final class Resumption<Output: Sendable>: Sendable {
    private typealias Status = Resumptions.Status

    private let function: StaticString
    private let file: StaticString
    private let line: UInt

    private let deinitBehavior: Cancellables.LeakBehavior
    private let status: @Sendable (Status) throws -> Void = Once<Status>().set
    private let continuation: UnsafeContinuation<Output, Swift.Error>

    private var leakFailureString: String {
        "LEAKED \(type(of: Self.self)):\(self). CREATED in \(function) @ \(file): \(line)"
    }

    public init(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        deinitBehavior: Cancellables.LeakBehavior = .assert,
        continuation: UnsafeContinuation<Output, Swift.Error>
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
            case .cancel: // Taking the combine approach...
                continuation.resume(throwing: LeakedError())
            case .assert: // Taking the NIO approach...
                assertionFailure("ASSERTION FAILURE: \(self.leakFailureString)") // Taking the NIO approach
            case .fatal:  // Taking the Chuck Norris approach
                fatalError("FATAL ERROR: \(self.leakFailureString)")
        }
    }
}

extension Resumption: Identifiable, Equatable, Hashable {
    public var id: ObjectIdentifier { ObjectIdentifier(self) }

    public static func == (lhs: Resumption<Output>, rhs: Resumption<Output>) -> Bool {
        lhs.id == rhs.id
    }
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self)
    }
}

public extension Resumption {
    @Sendable func resume(returning output: Output) throws -> Void {
        try status(.resumed)
        continuation.resume(returning: output)
    }

    @Sendable func resume(throwing error: Swift.Error) throws -> Void {
        try status(.resumed)
        continuation.resume(throwing: error)
    }

    @Sendable func resume(with result: Result<Output, Swift.Error>) throws -> Void {
        try status(.resumed)
        switch result {
            case let .success(value): continuation.resume(returning: value)
            case let .failure(error): continuation.resume(throwing: error)
        }
    }
}

public extension Resumption where Output == Void {
    @Sendable func resume() throws -> Void {
        try resume(returning: ())
    }
}

public func pause<Output>(
    function: StaticString = #function,
    file: StaticString = #file,
    line: UInt = #line,
    deinitBehavior: Cancellables.LeakBehavior = .assert,
    for: Output.Type = Output.self,
    _ resumingWith: (Resumption<Output>) -> Void
) async throws -> Output {
    try await withUnsafeThrowingContinuation { continuation in
        resumingWith(
            .init(function: function, file: file, line: line, deinitBehavior: deinitBehavior, continuation: continuation)
        )
    }
}
