//: [Previous](@previous)

import Atomics
import _Concurrency
import PlaygroundSupport
PlaygroundPage.current.needsIndefiniteExecution = true

extension Result {
    init(catching: () async throws -> Success) async where Failure == Swift.Error {
        do { self = try await .success(catching()) }
        catch { self = .failure(error) }
    }
}

public enum AtomicError<R: AtomicValue>: Error {
    case failedTransition(from: R, to: R, current: R)
}

public extension Result where Failure == Swift.Error {
    func set<R: AtomicValue>(
        atomic: ManagedAtomic<R>,
        from oldStatus: R,
        to newStatus: R
    ) -> Self {
        .init {
            let (success, original) = atomic.compareExchange(
                expected: oldStatus,
                desired: newStatus,
                ordering: .sequentiallyConsistent
            )
            guard success else {
                throw AtomicError.failedTransition(
                    from: oldStatus,
                    to: newStatus,
                    current: original
                )
            }
            return try get()
        }
    }
}

public enum EnqueueError<Element>: Error {
    case dropped(Element)
    case terminated
}

public enum Cancellables {
    @TaskLocal static var status = ManagedAtomic<Status>(.running)

    static var isCancelled: Bool {
        status.load(ordering: .sequentiallyConsistent) == .cancelled
    }

    enum Status: UInt8, Sendable, AtomicValue, Equatable {
        case running
        case finished
        case cancelled
    }
}

public struct CancellationFailureError: Error { }

public final class Cancellable<Output: Sendable> {
    typealias Status = Cancellables.Status
    private let task: Task<Output, Swift.Error>
    private let atomicStatus = ManagedAtomic<Status>(.running)

    public init(operation: @Sendable @escaping () async throws -> Output) {
        let atomic = atomicStatus
        self.task = .init {
            try await Cancellables.$status.withValue(atomic) {
                try await Result(catching: operation)
                    .set(atomic: atomic, from: Status.running, to: Status.finished)
                    .mapError {
                        guard let err = $0 as? AtomicError<Status>, case .failedTransition(_, _, .cancelled) = err else {
                            return $0
                        }
                        return CancellationError()
                    }
                    .get()
            }
        }
    }

    @Sendable public func cancel() throws {
        try Result<Void, Swift.Error>.success(())
            .set(atomic: atomicStatus, from: Status.running, to: Status.cancelled)
            .mapError {_ in CancellationFailureError() }
            .get()
        task.cancel()
    }

    public var value: Output {
        get async throws { try await task.value }
    }
    public var result: Result<Output, Swift.Error> {
        get async { await task.result }
    }

    deinit {
        guard atomicStatus.load(ordering: .sequentiallyConsistent) != .running else {
            assertionFailure("ABORTING DUE TO LEAKED \(type(of: Self.self))")
            try? cancel()
            return
        }
    }
}

enum Resumptions {
    enum Status: UInt8, AtomicValue, Equatable, Sendable {
        case waiting
        case resumed
    }
}

public struct LeakError: Swift.Error, Sendable { }

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
public final class Resumption<Output: Sendable>: @unchecked Sendable {
    typealias Status = Resumptions.Status

    private let atomicStatus = ManagedAtomic<Status>(.waiting)
    private let continuation: UnsafeContinuation<Output, Swift.Error>

    private var status: Status {
        atomicStatus.load(ordering: .sequentiallyConsistent)
    }

    private var leakFailureString: String {
        "ABORTING DUE TO LEAKED \(type(of: Self.self)):\(self)"
    }

    private var multipleResumeFailureString: String {
        "ABORTING DUE TO PREVIOUS RESUMPTION: \(type(of: Self.self)):\(self)"
    }

    public init(continuation: UnsafeContinuation<Output, Swift.Error>) {
        self.continuation = continuation
    }

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

    public func tryResume(returning output: Output) throws -> Void {
        switch set(status: .resumed) {
            case .success: return continuation.resume(returning: output)
            case .failure(let error): throw error
        }
    }

    public func tryResume(throwing error: Swift.Error) throws -> Void {
        switch set(status: .resumed) {
            case .success: return continuation.resume(throwing: error)
            case .failure(let error): throw error
        }
    }
}

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
public func withResumption<Output>(
    _ resumingWith: (Resumption<Output>) -> Void
) async throws -> Output {
    try await withUnsafeThrowingContinuation { continuation in
        resumingWith(.init(continuation: continuation) )
    }
}

public struct TimeoutError: Swift.Error, Sendable { }

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
func process<Output: Sendable>(
    timeout: UInt64,
    _ process: @escaping () async -> Output
) -> Cancellable<Output> {
    .init {
        var resultCancellable: Cancellable<Output>!
        let resumption = try! await withResumption { outer in
            resultCancellable = .init {
                try await withResumption { inner in try! outer.tryResume(returning: inner) }
            }
        }
        let processCancellable: Cancellable<Void> = .init {
            let output = await process()
            try? resumption.tryResume(returning: output)
        }
        let timeoutCancellable: Cancellable<Void> = .init {
            try? await Task.sleep(nanoseconds: timeout)
            try? resumption.tryResume(throwing: TimeoutError())
        }
        return try await withTaskCancellationHandler(
            operation: {
                try await resultCancellable.value
            },
            onCancel: {
                try? resumption.tryResume(throwing: CancellationError())
                try? processCancellable.cancel()
                try? timeoutCancellable.cancel()
            }
        )
    }
}

let cancellable1 = process(timeout: 100_000_000) { 13 }
let cancellationResult1 = Result {
    try cancellable1.cancel()
}
print(cancellationResult1)
let result1 = await cancellable1.result
print(result1)

//=================================================

let cancellable3 = process(timeout: 100_000_000) {
    try? await Task.sleep(nanoseconds: 200_000_000)
    return 13
}
let cancellationResult3 = Result { try cancellable3.cancel() }
print(cancellationResult3)
let result3 = await cancellable3.result
print(result3)

PlaygroundPage.current.finishExecution()

//: [Next](@next)
