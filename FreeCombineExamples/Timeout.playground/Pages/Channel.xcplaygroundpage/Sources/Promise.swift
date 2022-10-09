public enum Promises {
    enum Status: UInt8, Equatable, RawRepresentable {
        case waiting
        case succeeded
        case failed
    }
}

public final class Promise<Output> {
    typealias Status = Promises.Status
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

    /*:
     [leaks of NIO EventLoopPromises](https://github.com/apple/swift-nio/blob/48916a49afedec69275b70893c773261fdd2cfde/Sources/NIOCore/EventLoopFuture.swift#L431)
     */
    deinit {
        guard atomicStatus.load(ordering: .sequentiallyConsistent) != Status.waiting.rawValue else {
            assertionFailure("ABORTING DUE TO LEAKED \(type(of: Self.self))")
            try? cancel()
            return
        }
    }

    private func set(status newStatus: Status) throws -> Resumption<Output> {
        try Result<Void, Swift.Error>.success(())
            .set(atomic: atomicStatus, from: Status.waiting, to: newStatus)
            .get()

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
        try fail(CancellationError())
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
