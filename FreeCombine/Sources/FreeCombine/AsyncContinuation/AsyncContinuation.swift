//
//  AsyncContinuations.swift
//  
//
//  Created by Van Simmons on 9/13/22.
//

public struct AsyncContinuation<
    Output: Sendable,
    Return: Sendable
>: Sendable {
    private let call: @Sendable (
        Resumption<Void>,
        @escaping @Sendable (Output) async throws -> Return
    ) -> Cancellable<Return>

    internal init(
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
        call(onStartup, { result in
            guard !Task.isCancelled else {
                throw Cancellables.Error.cancelled
            }
            return try await downstream(result)
        } )
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
        let _: Void = try! await withResumption { resumption in
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

public extension AsyncContinuation {
    func map<T>(
        _ transform: @escaping (Output) async -> T
    ) -> AsyncContinuation<T, Return> {
        .init { resumption, downstream in
            self(onStartup: resumption) { a in
                try await downstream(transform(a))
            }
        }
    }

    func delay(
        _ nanoseconds: UInt64
    ) -> Self {
        .init { resumption, downstream in
            self(onStartup: resumption) { r in
                try? await Task.sleep(nanoseconds: nanoseconds)
                return try await downstream(r)
            }
        }
    }
    func tryMap<T>(
        _ transform: @escaping (Output) async throws -> T
    ) -> AsyncContinuation<T, Return> {
        .init { resumption, downstream in
            self(onStartup: resumption) { a in
                try await downstream(transform(a))
            }
        }
    }

    func flatMap<T>(
        _ transform: @escaping (Output) async -> AsyncContinuation<T, Return>
    ) -> AsyncContinuation<T, Return> {
        .init { resumption, downstream in
            self(onStartup: resumption) { a in
                try await transform(a)(downstream).value
            }
        }
    }
}
