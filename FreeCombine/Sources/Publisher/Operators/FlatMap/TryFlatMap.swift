//
//  File.swift
//  
//
//  Created by Van Simmons on 12/10/22.
//

import Core

public extension Publisher {
    func tryFlatMap<T>(
        _ transform: @escaping (Output) async throws -> Publisher<T>
    ) -> Publisher<T> {
        .init { resumption, downstream in
            self(onStartup: resumption) { r in
                switch r {
                case .value(let a):
                    var c: Publisher<T>!
                    do { c = try await transform(a) }
                    catch { return try await downstream(.completion(.failure(error))) }
                    return try await c(flattener(downstream)).value
                case let .completion(value):
                    return try await downstream(.completion(value))
            } }
        }
    }
}
