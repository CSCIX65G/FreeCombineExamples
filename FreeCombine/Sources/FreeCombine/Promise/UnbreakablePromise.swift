//
//  UnbreakablePromise.swift
//  
//
//  Created by Van Simmons on 9/15/22.
//
import Atomics

public enum UnbreakablePromises {
    public enum Status: UInt8, Equatable, AtomicValue {
        case waiting
        case succeeded
    }
}

public final class UnbreakablePromise<Output> {
    typealias Status = UnbreakablePromises.Status
    private let function: StaticString
    private let file: StaticString
    private let line: UInt

    private let atomicStatus = ManagedAtomic<Status>(.waiting)
    private let resumption: UnfailingResumption<Output>

    public let uncancellable: Uncancellable<Output>

    public init(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line
    ) async {
        self.function = function
        self.file = file
        self.line = line
        var uc: Uncancellable<Output>!
        self.resumption = await withUnfailingResumption { outer in
            uc = .init(function: function, file: file, line: line) { await withUnfailingResumption(outer.resume) }
        }
        self.uncancellable = uc
    }

    var status: Status {
        atomicStatus.load(ordering: .sequentiallyConsistent)
    }

    /*:
     This is similar to how [leaks of NIO EventLoopPromises](https://github.com/apple/swift-nio/blob/48916a49afedec69275b70893c773261fdd2cfde/Sources/NIOCore/EventLoopFuture.swift#L431) are treated
     */
    deinit {
        guard status != .waiting else {
            Assertion.assertionFailure("ABORTING DUE TO LEAKED \(type(of: Self.self)):\(self)  CREATED in \(function) @ \(file): \(line)")
            return
        }
    }

    private func setSucceeded() throws -> UnfailingResumption<Output> {
        let (success, original) = atomicStatus.compareExchange(
            expected: Status.waiting,
            desired: Status.succeeded,
            ordering: .sequentiallyConsistent
        )
        guard success else {
            throw AtomicError.failedTransition(
                from: .waiting,
                to: .succeeded,
                current: original
            )
        }
        return resumption
    }
}

// async variables
public extension UnbreakablePromise {
    var value: Output {
        get async throws { await uncancellable.value  }
    }
}

public extension UnbreakablePromise {
    func succeed(_ arg: Output) throws {
        try setSucceeded().resume(returning: arg)
    }
}

public extension UnbreakablePromise where Output == Void {
    func succeed() throws -> Void {
        try succeed(())
    }
}
