//
//  Promise.swift
//  UsingFreeCombine
//
//  Created by Van Simmons on 9/5/22.
//
import Atomics

public enum Promises {
    enum Status: UInt8, Equatable, AtomicValue {
        case waiting
        case succeeded
        case failed
    }
}

public final class Promise<Output> {
    typealias Status = Promises.Status

    private let function: StaticString
    private let file: StaticString
    private let line: UInt

    private let atomicStatus = ManagedAtomic<Status>(.waiting)
    private let resumption: Resumption<Output>
    public let cancellable: Cancellable<Output>

    public init(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line
    ) async {
        self.function = function
        self.file = file
        self.line = line
        var lc: Cancellable<Output>!
        self.resumption = try! await withResumption { outer in
            lc = .init(function: function, file: file, line: line) { try await withResumption(outer.resume) }
        }
        self.cancellable = lc
    }

    /*:
     [leaks of NIO EventLoopPromises](https://github.com/apple/swift-nio/blob/48916a49afedec69275b70893c773261fdd2cfde/Sources/NIOCore/EventLoopFuture.swift#L431)
     */
    deinit {
        guard atomicStatus.load(ordering: .sequentiallyConsistent) != .waiting else {
            assertionFailure("ABORTING DUE TO LEAKED \(type(of: Self.self)) CREATED in \(function) @ \(file): \(line)")
            try? cancel()
            return
        }
        try? cancellable.cancel()
    }

    private func set(status newStatus: Status) throws -> Resumption<Output> {
        try Result<Void, Swift.Error>.success(())
            .set(atomic: atomicStatus, from: .waiting, to: newStatus)
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

public extension Promise {
    var future: Future<Output> {
        .init { resumption, downstream in .init {
            resumption.resume()
            await downstream(self.result)
        } }
    }
}
