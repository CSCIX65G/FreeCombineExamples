//
//  Future.swift
//  UsingFreeCombine
//
//  Created by Van Simmons on 9/5/22.
//

public struct Future<Output: Sendable>: Sendable {
    private let call: @Sendable (
        Resumption<Void>,
        @escaping @Sendable (Result<Output, Swift.Error>) async -> Void
    ) -> Cancellable<Void>

    internal init(
        _ call: @escaping @Sendable (
            Resumption<Void>,
            @escaping @Sendable (Result<Output, Swift.Error>) async -> Void
        ) -> Cancellable<Void>
    ) {
        self.call = call
    }
}

extension Future {
    @discardableResult
    func callAsFunction(
        onStartup: Resumption<Void>,
        _ downstream: @escaping @Sendable (Result<Output, Swift.Error>) async -> Void
    ) -> Cancellable<Void> {
        call(onStartup, { result in
            guard !Task.isCancelled else {
                return await downstream(.failure(Cancellables.Error.cancelled))
            }
            return await downstream(result)
        } )
    }

    @discardableResult
    func sink(
        onStartup: Resumption<Void>,
        _ downstream: @escaping @Sendable (Result<Output, Swift.Error>) async -> Void
    ) -> Cancellable<Void> {
        self(onStartup: onStartup, downstream)
    }

    @discardableResult
    func callAsFunction(
        _ downstream: @escaping @Sendable (Result<Output, Swift.Error>) async -> Void
    ) async -> Cancellable<Void> {
        var cancellable: Cancellable<Void>!
        let _: Void = try! await withResumption { resumption in
            cancellable = self(onStartup: resumption, downstream)
        }
        return cancellable
    }

    @discardableResult
    func sink(
        _ downstream: @escaping @Sendable (Result<Output, Swift.Error>) async -> Void
    ) async -> Cancellable<Void> {
        await self(downstream)
    }
}

public extension Future {
    func map<T>(
        _ transform: @escaping (Output) async -> T
    ) -> Future<T> {
        .init { resumption, downstream in
            self(onStartup: resumption) { r in switch r {
                case .success(let a):
                    return await downstream(.success(transform(a)))
                case let .failure(error):
                    return await downstream(.failure(error))
            } }
        }
    }

    func delay(
        _ nanoseconds: UInt64
    ) -> Self {
        .init { resumption, downstream in
            self(onStartup: resumption) { r in
                try? await Task.sleep(nanoseconds: nanoseconds)
                return await downstream(r)
            }
        }
    }
    func tryMap<T>(
        _ transform: @escaping (Output) async throws -> T
    ) -> Future<T> {
        .init { resumption, downstream in
            self(onStartup: resumption) { r in switch r {
                case .success(let a):
                    do { return try await downstream(.success(transform(a))) }
                    catch { return await downstream(.failure(error)) }
                case let .failure(error):
                    return await downstream(.failure(error))
            } }
        }
    }

    func flatMap<T>(
        _ transform: @escaping (Output) async -> Future<T>
    ) -> Future<T> {
        .init { resumption, downstream in
            self(onStartup: resumption) { r in switch r {
                case .success(let a):
                    _ = await transform(a)(downstream).result
                case let .failure(error):
                    await downstream(.failure(error))
            } }
        }
    }
}
