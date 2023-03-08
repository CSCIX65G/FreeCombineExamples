//
//  AsyncPromise.swift
//
//
//  Created by Van Simmons on 2/15/23.
//
import Core

public struct UnbreakableAsyncPromise<Value: Sendable>: Sendable {
    private let function: StaticString
    private let file: StaticString
    private let line: UInt
    private let deinitBehavior: Uncancellables.LeakBehavior

    let promise: UnbreakablePromise<Value>
    let uncancellable: Uncancellable<Value>

    public init(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        deinitBehavior: Uncancellables.LeakBehavior = .assert,
        _ value: Value? = .none
    ) {
        let localPromise: UnbreakablePromise<Value> = .init(
            function: function,
            file: file,
            line: line,
            deinitBehavior: deinitBehavior,
            value
        )

        self.function = function
        self.file = file
        self.line = line
        self.deinitBehavior = deinitBehavior
        self.promise = localPromise
        self.uncancellable = .init(function: function, file: file, line: line, deinitBehavior: deinitBehavior) {
            await unfailingPause(for: Value.self) { resumption in
                try! localPromise.wait(with: resumption)
            }
        }
    }
}

public extension UnbreakableAsyncPromise {
    func succeed() throws -> Void where Value == Void {
        try succeed(())
    }

    func succeed(_ value: Value) throws -> Void {
        try promise.succeed(value)
    }

    var value: Value {
        get async throws { await uncancellable.value }
    }
}
