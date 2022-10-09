//
//  Join.swift
//  
//
//  Created by Van Simmons on 9/21/22.
//
public extension Future {
    func join<B>() -> Future<B> where Output == Future<B> {
        .init { resumption, downstream in
            self(onStartup: resumption) { r in switch r {
                case .success(let a):
                    _ = await a(downstream).result
                case let .failure(error):
                    return await downstream(.failure(error))
            } }
        }
    }
}

public extension Publisher {
    func join<B>() -> Publisher<B> where Output == Publisher<B> {
        .init { resumption, downstream in
            self(onStartup: resumption) { r in switch r {
                case .value(let a):
                    return try await a(downstream).value
                case let .completion(.failure(error)):
                    return try await downstream(.completion(.failure(error)))
                case .completion(.finished):
                    return try await downstream(.completion(.finished))
            } }
        }
    }
}

public extension Cancellable {
    func join<T>() -> Cancellable<T> where Output == Cancellable<T> {
        .init {
            let inner = try await self.value
            guard !Cancellables.isCancelled else {
                try? inner.cancel()
                throw CancellationError()
            }
            let value = try await inner.value
            return value
        }
    }
}

extension Uncancellable {
    public func join<T>() -> Uncancellable<T> where Output == Uncancellable<T> {
        .init { await self.value.value }
    }
}
