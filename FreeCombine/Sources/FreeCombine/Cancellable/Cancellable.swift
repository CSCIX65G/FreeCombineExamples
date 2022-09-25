//
//  Cancellable.swift
//  UsingFreeCombine
//
//  Created by Van Simmons on 9/5/22.
//
import Atomics

public final class Cancellable<Output: Sendable> {
    public typealias Error = Cancellables.Error
    public typealias Status = Cancellables.Status

    private let function: StaticString
    private let file: StaticString
    private let line: UInt

    private let task: Task<Output, Swift.Error>
    private let atomicStatus = ManagedAtomic<UInt8>(Status.running.rawValue)

    public init(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        operation: @escaping @Sendable () async throws -> Output
    ) {
        self.function = function
        self.file = file
        self.line = line
        let atomic = atomicStatus
        self.task = .init {
            try await Cancellables.$status.withValue(atomic) {
                try await Result(catching: operation)
                    .set(atomic: atomic, from: Status.running, to: Status.finished)
                    .get()
            }
        }
    }
    
    @Sendable public func cancel() throws {
        try Result<Void, Swift.Error>.success(())
            .set(atomic: atomicStatus, from: Status.running, to: Status.cancelled)
            .get()
        // Allow the task cancellation handlers to run
        // These are opaque so we can't replace them with wrappers
        task.cancel()
    }

    public var value: Output {
        get async throws { try await task.value }
    }
    public var result: Result<Output, Swift.Error> {
        get async { await task.result }
    }

    /*:
     [leaks of NIO EventLoopPromises](https://github.com/apple/swift-nio/blob/48916a49afedec69275b70893c773261fdd2cfde/Sources/NIOCore/EventLoopFuture.swift#L431)
     are dealt with in the same way
     */
    deinit {
        guard atomicStatus.load(ordering: .sequentiallyConsistent) != Status.running.rawValue else {
            Assertion.assertionFailure(
                "ABORTING DUE TO LEAKED \(type(of: Self.self)) CREATED in \(function) @ \(file): \(line)"
            )
            try? cancel()
            return
        }
    }
}

extension Cancellable: Hashable {
    public static func == (lhs: Cancellable<Output>, rhs: Cancellable<Output>) -> Bool {
        lhs.task == rhs.task
    }
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self)
    }
}

public extension Cancellable {
    var future: Future<Output> {
        .init { resumption, downstream in
            .init {
                resumption.resume()
                await downstream(self.result)
            }
        }
    }
}
