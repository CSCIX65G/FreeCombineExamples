//
//  AsyncContinuations.swift
//  
//
//  Created by Van Simmons on 9/13/22.
//

public struct AsyncContinuation<Output: Sendable, Return>: Sendable {
    private let call: @Sendable (
        Resumption<Void>,
        @escaping @Sendable (Output) async throws -> Return
    ) -> Cancellable<Return>

    init(
        _ call: @escaping @Sendable (
            Resumption<Void>,
            @escaping @Sendable (Output) async throws -> Return
        ) -> Cancellable<Return>
    ) {
        self.call = call
    }
}

extension AsyncContinuation {
    @discardableResult
    func callAsFunction(
        onStartup: Resumption<Void>,
        _ downstream: @escaping @Sendable (Output) async throws -> Return
    ) -> Cancellable<Return> {
        call(onStartup) { result in
            guard !Cancellables.isCancelled else { throw CancellationError() }
            return try await downstream(result)
        }
    }

    @discardableResult
    func sink(
        onStartup: Resumption<Void>,
        _ downstream: @escaping @Sendable (Output) async throws -> Return
    ) -> Cancellable<Return> {
        self(onStartup: onStartup, downstream)
    }

    @discardableResult
    func callAsFunction(
        _ downstream: @escaping @Sendable (Output) async throws -> Return
    ) async -> Cancellable<Return> {
        var cancellable: Cancellable<Return>!
        let _: Void = try! await pause { resumption in
            cancellable = self(onStartup: resumption, downstream)
        }
        return cancellable
    }

    @discardableResult
    func sink(
        _ downstream: @escaping @Sendable (Output) async throws -> Return
    ) async -> Cancellable<Return> {
        await self(downstream)
    }
}
