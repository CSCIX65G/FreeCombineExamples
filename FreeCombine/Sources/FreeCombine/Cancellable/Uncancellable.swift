//
//  Uncancellable.swift
//
//
//  Created by Van Simmons on 9/7/22.
//
import Atomics

public enum Uncancellables {
    @TaskLocal static var status = ManagedAtomic<Bool>(false)
}

public final class Uncancellable<Output: Sendable> {
    private let function: StaticString
    private let file: StaticString
    private let line: UInt

    private let task: Task<Output, Never>
    private let atomicStatus = ManagedAtomic<Bool>(false)

    private var status: Bool {
        atomicStatus.load(ordering: .sequentiallyConsistent)
    }

    private var leakFailureString: String {
        "ABORTING DUE TO LEAKED \(type(of: Self.self)):\(self)  CREATED in \(function) @ \(file): \(line)"
    }

    public init(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        operation: @escaping @Sendable () async -> Output
    ) {
        self.function = function
        self.file = file
        self.line = line

        let atomic = atomicStatus
        self.task = .init {
            let retValue = await operation()
            atomic.store(true, ordering: .sequentiallyConsistent)
            return retValue
        }
    }

    /*:
     [leaks of NIO EventLoopPromises](https://github.com/apple/swift-nio/blob/48916a49afedec69275b70893c773261fdd2cfde/Sources/NIOCore/EventLoopFuture.swift#L431)
     */
    deinit {
        let isEffectfulType = Output.self == Void.self || Output.self == Never.self
        guard status, !isEffectfulType else {
            Assertion.assertionFailure(leakFailureString)
            return
        }
    }

    public var value: Output {
        get async { await task.value }
    }
}
