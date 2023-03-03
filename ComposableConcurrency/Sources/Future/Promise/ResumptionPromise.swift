//
//  Promise.swift
//  
//
//  Created by Van Simmons on 2/12/23.
//
import Atomics
import Core

public final class ResumptionPromise<Output: Sendable>: Sendable {
    private let function: StaticString
    private let file: StaticString
    private let line: UInt
    private let deinitBehavior: Cancellables.LeakBehavior
    
    private let resumption: Resumption<Output>
    public let cancellable: Cancellable<Output>

    private var leakFailureString: String {
        "LEAKED \(type(of: Self.self)):\(self). CREATED in \(function) @ \(file): \(line)"
    }

    public init(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        deinitBehavior: Cancellables.LeakBehavior = .assert
    ) async {
        self.function = function
        self.file = file
        self.line = line
        self.deinitBehavior = deinitBehavior

        var localCancellable: Cancellable<Output>!
        self.resumption = try! await pause { outer in
            localCancellable = .init(function: function, file: file, line: line, deinitBehavior: deinitBehavior) {
                try await pause(function: function, file: file, line: line, deinitBehavior: deinitBehavior) { inner in
                    try! outer.resume(returning: inner)
                }
            }
        }
        self.cancellable = localCancellable
    }

    public static func promise(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        deinitBehavior: Cancellables.LeakBehavior = .assert
    ) -> Uncancellable<ResumptionPromise<Output>> {
        .init { await .init(function: function, file: file, line: line, deinitBehavior: deinitBehavior) }
    }
}

public extension ResumptionPromise {
    var result: Result<Output, Swift.Error> {
        get async { await cancellable.result }
    }

    var value: Output {
        get async throws { try await cancellable.value  }
    }
}

public extension ResumptionPromise {
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
        try resumption.resume(returning: arg)
    }

    func fail(_ error: Swift.Error) throws {
        try resumption.resume(throwing: error)
    }
}

public extension ResumptionPromise where Output == Void {
    func succeed() throws -> Void {
        try succeed(())
    }
}
