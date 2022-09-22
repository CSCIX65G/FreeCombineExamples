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

    private let task: Task<Output, Swift.Error>
    private let atomicStatus = ManagedAtomic<UInt8>(Status.running.rawValue)

    public let function: StaticString
    public let file: StaticString
    public let line: UInt

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

    public var isCancelled: Bool {
        atomicStatus.load(ordering: .sequentiallyConsistent) == Status.cancelled.rawValue
    }
    public var isFinished: Bool {
        atomicStatus.load(ordering: .sequentiallyConsistent) == Status.finished.rawValue
    }
    
    public var status: Status { Status.get(atomic: atomicStatus) }

    @Sendable public func cancel() throws {
        try Result<Void, Swift.Error>.success(())
            .set(
                atomic: atomicStatus,
                from: Cancellables.Status.running,
                to: Cancellables.Status.cancelled
            )
            .get()
        // As a courtesy to older code...
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
        guard status != .running else {
            Assertion.assertionFailure(
                "ABORTING DUE TO LEAKED \(type(of: Self.self)) CREATED in \(function) @ \(file): \(line)"
            )
            try? cancel()
            return
        }
    }
}

public extension Cancellable {
    func map<T>(_ transform: @escaping (Output) async -> T) -> Cancellable<T> {
        .init {
            try await withTaskCancellationHandler(
                operation: {
                    let value = try await self.value
                    guard self.status != .cancelled else { throw Error.cancelled }
                    let transformed = await transform(value)
                    return transformed
                },
                onCancel: { try? self.cancel() }
            )
        }
    }
}

public extension Cancellable {
    func join<T>() -> Cancellable<T> where Output == Cancellable<T> {
        .init {
            let inner = try await self.value
            guard self.status != .cancelled else {
                try? inner.cancel()
                throw Error.cancelled
            }
            let value = try await inner.value
            return value
        }
    }
}

public extension Cancellable {
    func flatMap<T>(
        _ transform: @escaping (Output) async -> Cancellable<T>
    ) -> Cancellable<T> {
        map(transform).join()
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
