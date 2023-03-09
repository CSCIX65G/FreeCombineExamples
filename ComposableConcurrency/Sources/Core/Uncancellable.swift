//
//  Uncancellable.swift
//  
//
//  Created by Van Simmons on 2/12/23.
//
import SendableAtomics
import Atomics

public enum Uncancellables {
    public enum LeakBehavior: UInt8, Sendable, AtomicValue, Equatable {
        case assert
        case fatal
    }

    public enum Status: UInt8, Sendable, AtomicValue, Equatable {
        case finished
    }
}

public final class Uncancellable<Output> {
    typealias Status = Uncancellables.Status

    private let function: StaticString
    private let file: StaticString
    private let line: UInt
    private let deinitBehavior: Uncancellables.LeakBehavior

    private let setStatus: @Sendable (Status) throws -> Void
    private let task: Task<Output, Never>

    private var leakFailureString: String {
        "LEAKED \(type(of: Self.self)):\(self). CREATED in \(function) @ \(file): \(line)"
    }

    @Sendable public init(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        deinitBehavior: Uncancellables.LeakBehavior = .assert,
        operation: @Sendable @escaping () async -> Output
    ) {
        let localSetStatus = Once<Status>().set

        self.function = function
        self.file = file
        self.line = line
        self.deinitBehavior = deinitBehavior
        self.setStatus = localSetStatus
        self.task = .init {
            let value = await operation()
            do { try localSetStatus(.finished) }
            catch {
                guard Output.self == Void.self else {
                    fatalError("Cannot fail")
                }
                return value
            }
            return value
        }
    }

    deinit {
        do { try setStatus(.finished) }
        catch { return }
        switch deinitBehavior {
            case .assert: // Taking the NIO approach...
                assertionFailure("ASSERTION FAILURE: \(self.leakFailureString)") // Taking the NIO approach
            case .fatal:  // Taking the Chuck Norris approach
                fatalError("FATAL ERROR: \(self.leakFailureString)")
        }
    }
}

extension Uncancellable: Sendable where Output: Sendable { }

public extension Uncancellable {
    var value: Output { get async { await task.value } }
}

public extension Uncancellable where Output == Void {
    @Sendable func release() throws -> Void {
        try setStatus(.finished)
    }
}
