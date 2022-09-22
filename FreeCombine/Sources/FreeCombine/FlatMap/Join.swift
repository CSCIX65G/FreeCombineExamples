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

