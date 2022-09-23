//
//  UnbreakablePromise.swift
//  
//
//  Created by Van Simmons on 9/15/22.
//
import Atomics

public final class UnbreakablePromise<Output> {
    public enum Error: Swift.Error, Equatable {
        case alreadySucceeded
        case internalInconsistency
    }

    public enum Status: UInt8, Equatable, RawRepresentable {
        case waiting
        case succeeded
    }

    private let function: StaticString
    private let file: StaticString
    private let line: UInt

    private let atomicStatus = ManagedAtomic<UInt8>(Status.waiting.rawValue)
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
        .init(rawValue: atomicStatus.load(ordering: .sequentiallyConsistent))!
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
            expected: Status.waiting.rawValue,
            desired: Status.succeeded.rawValue,
            ordering: .sequentiallyConsistent
        )
        guard success else {
            switch original {
                case Status.succeeded.rawValue: throw Error.alreadySucceeded
                default: throw Error.internalInconsistency
            }
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
