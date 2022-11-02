//
//  Uncancellable.swift
//
//
//  Created by Van Simmons on 9/7/22.
//
import Atomics

public enum Uncancellables {
    @TaskLocal static var status = ManagedAtomic<Bool>(false)

    enum Status: UInt8, Sendable, AtomicValue, Equatable {
        case running
        case finished
        case released
    }
}

public final class Uncancellable<Output: Sendable> {
    typealias Status = Uncancellables.Status
    private let function: StaticString
    private let file: StaticString
    private let line: UInt

    private let task: Task<Output, Never>
    private let atomicStatus = ManagedAtomic<Status>(.running)

    private var status: Status {
        atomicStatus.load(ordering: .sequentiallyConsistent)
    }

    private var leakFailureString: String {
        "ABORTING DUE TO LEAKED \(type(of: Self.self)):\(self)  CREATED in \(function) @ \(file): \(line)"
    }

    public init(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        released: Bool = false,
        operation: @escaping @Sendable () async -> Output
    ) {
        self.function = function
        self.file = file
        self.line = line

        atomicStatus.store(released ? .released : .running, ordering: .sequentiallyConsistent)
        let atomic = atomicStatus
        self.task = .init {
            let retValue = await operation()
            (_, _) = atomic.compareExchange(expected: .running, desired: .finished, ordering: .sequentiallyConsistent)
            return retValue
        }
    }

    @Sendable public func release() throws {
        try Result<Void, Swift.Error>.success(())
            .set(atomic: atomicStatus, from: Status.running, to: Status.released)
            .mapError {_ in ReleaseError() }
            .get()
    }

    /*:
     [leaks of NIO EventLoopPromises](https://github.com/apple/swift-nio/blob/48916a49afedec69275b70893c773261fdd2cfde/Sources/NIOCore/EventLoopFuture.swift#L431)
     */
    deinit {
        guard status != .running else {
            Assertion.assertionFailure(leakFailureString)
            return
        }
    }

    public var value: Output {
        get async { await task.value }
    }
}

extension Uncancellable: Identifiable {
    public var id: ObjectIdentifier { ObjectIdentifier(self) }
}
