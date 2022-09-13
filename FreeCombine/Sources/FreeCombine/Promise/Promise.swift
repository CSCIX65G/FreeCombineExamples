//
//  Promise.swift
//  UsingFreeCombine
//
//  Created by Van Simmons on 9/5/22.
//
import Atomics

public final class Promise<Arg> {
    public enum Error: Swift.Error, Equatable {
        case alreadyCancelled
        case alreadyCompleted
        case alreadyFailed
        case internalInconsistency
    }

    public enum Status: UInt8, Equatable, RawRepresentable {
        case waiting
        case succeeded
        case failed
        case cancelled
    }

    private let atomic = ManagedAtomic<UInt8>(Status.waiting.rawValue)
    public let resumption: Resumption<Arg>
    public let cancellable: Cancellable<Arg>

    public init() async {
        var localCancellable: Cancellable<Arg>!
        self.resumption = try! await withResumption { outer in
            localCancellable = .init {
                try await withResumption(outer.resume)
            }
        }
        self.cancellable = localCancellable
    }

    public var canDeallocate: Bool { status != .waiting }

    deinit {
        guard canDeallocate else {
            assertionFailure("ABORTING DUE TO LEAKED \(type(of: Self.self))")
            try? cancel()
            return
        }
    }

    private func set(status newStatus: Status) throws -> Resumption<Arg> {
        let (success, original) = atomic.compareExchange(
            expected: Status.waiting.rawValue,
            desired: newStatus.rawValue,
            ordering: .sequentiallyConsistent
        )
        guard success else {
            switch original {
                case Status.succeeded.rawValue: throw Error.alreadyCompleted
                case Status.cancelled.rawValue: throw Error.alreadyCancelled
                case Status.failed.rawValue: throw Error.alreadyFailed
                default: throw Error.internalInconsistency
            }
        }
        return resumption
    }
}

// async variables
public extension Promise {
    var result: Result<Arg, Swift.Error> {
        get async { await cancellable.result }
    }

    var value: Arg {
        get async throws { try await cancellable.value  }
    }
}

// sync variables
public extension Promise {
    var status: Status {
        .init(rawValue: atomic.load(ordering: .sequentiallyConsistent))!
    }

    var isCancelled: Bool {
        cancellable.isCancelled
    }

    func succeed(_ arg: Arg) throws {
        try set(status: .succeeded).resume(returning: arg)
    }

    func cancel() throws {
        try set(status: .cancelled).resume(throwing: Cancellable<Arg>.Error.cancelled)
    }

    func fail(_ error: Swift.Error) throws {
        try set(status: .failed).resume(throwing: error)
    }
}

public extension Promise where Arg == Void {
    func succeed() throws -> Void {
        try succeed(())
    }
}

public extension Promise {
    var future: Future<Arg> {
        .init { resumption, downstream in .init {
            resumption.resume()
            await downstream(self.result)
        } }
    }
}


