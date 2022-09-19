//
//  Promise.swift
//  UsingFreeCombine
//
//  Created by Van Simmons on 9/5/22.
//
import Atomics

public final class Promise<Output> {
    public enum Error: Swift.Error, Equatable {
        case alreadySucceeded
        case alreadyFailed
        case internalInconsistency
    }

    public enum Status: UInt8, Equatable, RawRepresentable {
        case waiting
        case succeeded
        case failed
    }

    private let atomicStatus = ManagedAtomic<UInt8>(Status.waiting.rawValue)
    private let resumption: Resumption<Output>
    public let cancellable: Cancellable<Output>

    public init() async {
        var lc: Cancellable<Output>!
        self.resumption = try! await withResumption { outer in
            lc = .init { try await withResumption(outer.resume) }
        }
        self.cancellable = lc
    }

    var status: Status {
        .init(rawValue: atomicStatus.load(ordering: .sequentiallyConsistent))!
    }

    /*:
     [leaks of NIO EventLoopPromises](https://github.com/apple/swift-nio/blob/48916a49afedec69275b70893c773261fdd2cfde/Sources/NIOCore/EventLoopFuture.swift#L431)
     */
    deinit {
        guard status != .waiting else {
            assertionFailure("ABORTING DUE TO LEAKED \(type(of: Self.self))")
            try? cancel()
            return
        }
    }

    private func set(status newStatus: Status) throws -> Resumption<Output> {
        guard newStatus != .waiting else { throw Error.internalInconsistency }
        let (success, original) = atomicStatus.compareExchange(
            expected: Status.waiting.rawValue,
            desired: newStatus.rawValue,
            ordering: .sequentiallyConsistent
        )
        guard success else {
            switch original {
                case Status.succeeded.rawValue: throw Error.alreadySucceeded
                case Status.failed.rawValue: throw Error.alreadyFailed
                default: throw Error.internalInconsistency
            }
        }
        return resumption
    }
}

public extension Promise {
    var result: Result<Output, Swift.Error> {
        get async { await cancellable.result }
    }

    var value: Output {
        get async throws { try await cancellable.value  }
    }
}

public extension Promise {
    func cancel() throws {
        try fail(Cancellables.Error.cancelled)
    }

    func resolve(_ result: Result<Output, Swift.Error>) throws {
        switch result {
            case let .success(arg): try succeed(arg)
            case let .failure(error): try fail(error)
        }
    }

    func succeed(_ arg: Output) throws {
        try set(status: .succeeded).resume(returning: arg)
    }

    func fail(_ error: Swift.Error) throws {
        try set(status: .failed).resume(throwing: error)
    }
}

public extension Promise where Output == Void {
    func succeed() throws -> Void {
        try succeed(())
    }
}

public extension Promise {
    var future: Future<Output> {
        .init { resumption, downstream in .init {
            resumption.resume()
            await downstream(self.result)
        } }
    }
}
