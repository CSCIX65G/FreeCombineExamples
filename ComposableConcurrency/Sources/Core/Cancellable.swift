//
//  Cancellable.swift
//
//
//  Created by Van Simmons on 2/12/23.
//
import Atomics
import SendableAtomics

public enum Cancellables { }

public extension Cancellables {
    enum Status: UInt8, Sendable, AtomicValue, Equatable {
        case finished
        case cancelled
    }

    enum LeakBehavior: UInt8, Sendable, AtomicValue, Equatable {
        case cancel
        case assert
        case fatal
    }
}

public final class Cancellable<Output: Sendable>: Sendable {
    public typealias Status = Cancellables.Status
    public typealias LeakBehavior = Cancellables.LeakBehavior

    private let function: StaticString
    private let file: StaticString
    private let line: UInt
    private let deinitBehavior: LeakBehavior

    private let setStatus: @Sendable (Status) throws -> Void
    private let task: Task<Output, Swift.Error>

    private var leakFailureString: String {
        "LEAKED \(type(of: Self.self)):\(self). CREATED in \(function) @ \(file): \(line)"
    }

    @Sendable public init(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        deinitBehavior: LeakBehavior = .assert,
        operation: @Sendable @escaping () async throws -> Output
    ) {
        let localSetStatus = Once<Status>().set

        self.function = function
        self.file = file
        self.line = line
        self.deinitBehavior = deinitBehavior
        self.setStatus = localSetStatus
        self.task = .init {
            let result = await AsyncResult(catching: operation)
            try localSetStatus(.finished)
            return try result.get()
        }
    }

    deinit {
        do { try cancel() }
        catch { return }
        switch deinitBehavior {
            case .cancel: // Taking the combine approach...
                ()
            case .assert: // Taking the NIO approach...
                assertionFailure("ASSERTION FAILURE: \(self.leakFailureString)") // Taking the NIO approach
            case .fatal:  // Taking the Chuck Norris approach
                fatalError("FATAL ERROR: \(self.leakFailureString)")
        }
    }
}

public extension Cancellable {
    @Sendable func cancel() throws -> Void {
        try setStatus(.cancelled)
        task.cancel()
    }

    var value: Output { get async throws { try await task.value } }
    var result: Result<Output, Swift.Error> { get async { await task.result } }
}
