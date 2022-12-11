//: [Previous](@previous)

/*:
 [Swift Atomics](https://www.swift.org/blog/swift-atomics/)

 > The goal of this library is to enable intrepid systems programmers to start building synchronization constructs (such as concurrent data structures) directly in Swift.
 */
import Atomics
import PlaygroundSupport
PlaygroundPage.current.needsIndefiniteExecution = true

public enum AtomicError<R: RawRepresentable>: Error {
    case failedTransition(from: R, to: R, current: R?)
}

extension Result {
    init(catching: () async throws -> Success) async where Failure == Swift.Error {
        do { self = try await .success(catching()) }
        catch { self = .failure(error) }
    }
}

public extension Result where Failure == Swift.Error {
    func set<R: RawRepresentable>(
        atomic: ManagedAtomic<R.RawValue>,
        from oldStatus: R,
        to newStatus: R
    ) throws -> Self where R.RawValue: AtomicValue {
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
                    current: R(rawValue: original)
                )
            }
            return try get()
        }
    }
}

public enum Cancellables {
    enum Status: UInt8, Sendable, RawRepresentable, Equatable {
        case running
        case finished
        case cancelled
    }
}

public final class Cancellable<Output: Sendable> {
    typealias Status = Cancellables.Status

    private let task: Task<Output, Swift.Error>
    private let atomicStatus = ManagedAtomic<UInt8>(Status.running.rawValue)

    public init(operation: @escaping @Sendable () async throws -> Output) {
        let atomic = atomicStatus
        self.task = .init {
            try await Result(catching: operation)
                .set(atomic: atomic, from: Status.running, to: Status.finished)
                .get()
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
}
/*:
 ### Cancellation is _SYNCHRONOUSLY_ Failable
 */
let t1 = Cancellable<Int> {
    try await Task.sleep(nanoseconds: 500_000_000)
    try Task.checkCancellation()
    return 13
}
let t2 = Cancellable<Void> {
    try await Task.sleep(nanoseconds: 200_000_000)
    do { try t1.cancel() } catch {
        print("t2 cancellation failed!")
        throw error
    }
    print("t2 cancellation succeeded!")
    return
}
let t3 = Cancellable<Void> {
    try await Task.sleep(nanoseconds: 100_000_000)
    guard let value = try? await t1.result.get() else {
        print("t3 failed"); return
    }
    print("t3 succeeded, value = \(value)")
}
let t4 = Cancellable<Void> {
    try await Task.sleep(nanoseconds: 300_000_000)
    guard let value = try? await t1.result.get() else {
        print("t4 failed"); return
    }
    print("t4 succeeded, value = \(value)")
}

await t1.result
await t2.result
await t3.result
await t4.result

PlaygroundPage.current.finishExecution()

//: [Next](@next)
