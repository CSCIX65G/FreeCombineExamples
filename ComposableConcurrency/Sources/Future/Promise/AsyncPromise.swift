//
//  AsyncPromise.swift
//
//
//  Created by Van Simmons on 2/15/23.
//
import Core

public struct AsyncPromise<Value: Sendable>: Sendable {
    private let function: StaticString
    private let file: StaticString
    private let line: UInt
    private let deinitBehavior: Cancellables.LeakBehavior

    let promise: Promise<Value>
    let cancellable: Cancellable<Value>

    public init(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        deinitBehavior: Cancellables.LeakBehavior = .assert,
        _ value: Result<Value, Swift.Error>? = .none
    ) {
        let localPromise: Promise<Value> = .init(
            function: function,
            file: file,
            line: line,
            deinitBehavior: deinitBehavior, value
        )

        self.function = function
        self.file = file
        self.line = line
        self.deinitBehavior = deinitBehavior
        self.promise = localPromise
        self.cancellable = .init(function: function, file: file, line: line, deinitBehavior: deinitBehavior) {
            try await pause(for: Value.self) { resumption in
                do { try localPromise.wait(with: resumption) }
                catch { try? resumption.resume(throwing: error) }
            }
        }
    }
}

public extension AsyncPromise {
    func cancel() throws -> Void {
        try promise.cancel()
    }

    func fail(_ error: Swift.Error) throws -> Void {
        try promise.fail(error)
    }

    func succeed() throws -> Void where Value == Void {
        try succeed(())
    }

    func succeed(_ value: Value) throws -> Void {
        try promise.succeed(value)
    }

    func resolve(_ result: Result<Value, Swift.Error>) throws -> Void {
        try promise.resolve(result)
    }

    var value: Value {
        get async throws { try await cancellable.value }
    }

    var result: Result<Value, Swift.Error> {
        get async { await cancellable.result }
    }
}
