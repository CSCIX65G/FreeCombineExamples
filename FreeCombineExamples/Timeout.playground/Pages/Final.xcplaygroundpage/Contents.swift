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

public enum AtomicError<R: RawRepresentable>: Error {
    case failedTransition(from: R, to: R, current: R)
}

public extension Result where Failure == Swift.Error {
    func set<R: RawRepresentable>(
        atomic: ManagedAtomic<R.RawValue>,
        from oldStatus: R,
        to newStatus: R
    ) -> Self where R.RawValue: AtomicValue {
        .init {
            let (success, original) = atomic.compareExchange(
                expected: oldStatus.rawValue,
                desired: newStatus.rawValue,
                ordering: .sequentiallyConsistent
            )
            guard success else {
                throw AtomicError.failedTransition(
                    from: oldStatus,
                    to: newStatus,
                    current: R(rawValue: original)!
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
    @TaskLocal static var status = ManagedAtomic<UInt8>(Status.running.rawValue)

    static var isCancelled: Bool {
        status.load(ordering: .sequentiallyConsistent) == Status.cancelled.rawValue
    }

    enum Status: UInt8, Sendable, RawRepresentable, Equatable {
        case running
        case finished
        case cancelled
    }
}

public struct CancellationFailureError: Error { }

public final class Cancellable<Output: Sendable> {
    typealias Status = Cancellables.Status
    private let task: Task<Output, Swift.Error>
    private let atomicStatus = ManagedAtomic<UInt8>(Status.running.rawValue)

    public init(operation: @escaping @Sendable () async throws -> Output) {
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
        guard atomicStatus.load(ordering: .sequentiallyConsistent) != Status.running.rawValue else {
            assertionFailure("ABORTING DUE TO LEAKED \(type(of: Self.self))")
            try? cancel()
            return
        }
    }
}

@available(iOS 13.0, *)
public struct Channel<Element: Sendable> {
    private let continuation: AsyncStream<Element>.Continuation
    let stream: AsyncStream<Element>

    public init(
        _: Element.Type = Element.self,
        buffering: AsyncStream<Element>.Continuation.BufferingPolicy = .bufferingOldest(1)
    ) {
        var localContinuation: AsyncStream<Element>.Continuation!
        stream = .init(bufferingPolicy: buffering) { localContinuation = $0 }
        continuation = localContinuation
    }

    func tryYield(_ value: Element) throws -> Void {
        switch continuation.yield(value) {
            case .enqueued: return
            case .dropped(let element): throw EnqueueError.dropped(element)
            case .terminated: throw EnqueueError<Element>.terminated
            @unknown default: fatalError("Unknown error")
        }
    }

    func finish() {
        continuation.finish()
    }
}

public enum Either<Left, Right> {
    case left(Left)
    case right(Right)
}

public struct Or<Left, Right> {
    enum Current {
        case nothing
        case complete(Either<Left, Right>)
    }

    public enum Action {
        case left(Left)
        case right(Right)
    }

    public struct State {
        var leftCancellable: Cancellable<Void>
        var rightCancellable: Cancellable<Void>
        var current: Current = .nothing
    }
}

public struct TimeoutError: Swift.Error { }

func process<Output>(
    timeout: UInt64,
    _ process: @escaping () async -> Output
) -> Cancellable<Output> {
    let channel = Channel<Or<Output, Void>.Action>()
    let processCancellable: Cancellable<Void> = .init {
        let result = await process()
        try? channel.tryYield(.left(result))
    }
    let timeoutCancellable: Cancellable<Void> = .init {
        try await Task.sleep(nanoseconds: timeout)
        try? channel.tryYield(.right(()))
    }
    return .init { try await withTaskCancellationHandler(
        operation: {
            var state = Or<Output, Void>.State(
                leftCancellable: processCancellable,
                rightCancellable: timeoutCancellable
            )
            for await action in channel.stream {
                channel.finish()
                switch (action, state.current) {
                    case let (.left(leftResult), .nothing):
                        state.current = .complete(.left(leftResult))
                        try? timeoutCancellable.cancel()
                    case (.right, .nothing):
                        state.current = .complete(.right(()))
                        try? processCancellable.cancel()
                    default:
                        ()
                }
            }
            switch state.current {
                case .nothing: throw CancellationError()
                case .complete(.left(let value)): return value
                case .complete(.right): throw TimeoutError()
            }
        },
        onCancel: {
            channel.finish()
            try? processCancellable.cancel()
            try? timeoutCancellable.cancel()
        } )
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
