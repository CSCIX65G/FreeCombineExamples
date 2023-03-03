//
//  Cancellable+Inits.swift
//  
//
//  Created by Van Simmons on 2/19/23.
//
import Atomics
import Core

public extension Cancellables {
    enum CancellationMode: UInt8, Sendable, AtomicValue, Equatable {
        case cooperative
        case immediate
    }
}

public extension Cancellable {
    convenience init(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        deinitBehavior: Cancellables.LeakBehavior = .assert,
        cancellationMode: Cancellables.CancellationMode,
        _ process: @Sendable @escaping () async throws -> Output
    ) {
        if cancellationMode == .cooperative {
            self.init(operation: process)
        } else {
            let promise = Promise<Output>()

            let processCancellable: Cancellable<Void> = .init(function: function, file: file, line: line, deinitBehavior: deinitBehavior) {
                do { try await promise.succeed(process()) }
                catch { try? promise.fail(error) }
            }

            self.init(function: function, file: file, line: line, deinitBehavior: deinitBehavior) {
                try await withTaskCancellationHandler(
                    operation: {
                        let result = await promise.result
                        try? processCancellable.cancel()
                        return try result.get()
                    },
                    onCancel: {
                        try? promise.fail(CancellationError())
                    }
                )
            }
        }
    }
}

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
public extension Cancellable {
    convenience init(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        deinitBehavior: Cancellables.LeakBehavior = .assert,
        timeoutAfter duration: Swift.Duration,
        _ process: @escaping () async throws -> Output
    ) {
        let promise = Promise<Output>()

        let processCancellable: Cancellable<Void> = .init(function: function, file: file, line: line, deinitBehavior: deinitBehavior) {
            do { try await promise.succeed(process()) }
            catch { try? promise.fail(error) }
        }

        let timeoutCancellable: Cancellable<Void> = .init(function: function, file: file, line: line, deinitBehavior: deinitBehavior) {
            try await Task.sleep(for : duration)
            try? promise.fail(TimeoutError())
        }

        self.init(function: function, file: file, line: line, deinitBehavior: deinitBehavior) {
            try await withTaskCancellationHandler(
                operation: {
                    let result = await promise.result
                    try? processCancellable.cancel()
                    try? timeoutCancellable.cancel()
                    return try result.get()
                },
                onCancel: {
                    try? promise.fail(CancellationError())
                }
            )
        }
    }
}
