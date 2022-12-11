import Atomics

public enum Cancellables {
    enum Status: UInt8, Sendable, RawRepresentable, Equatable {
        case running
        case finished
        case cancelled
    }
    @TaskLocal static var status = ManagedAtomic<UInt8>(Status.running.rawValue)
    static var isCancelled: Bool {
        status.load(ordering: .sequentiallyConsistent) == Status.cancelled.rawValue
    }
}

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
}
