//
//  TryFlatMap.swift
//  
//
//  Created by Van Simmons on 9/18/22.
//
extension Future {
    func tryFlatMap<T>(
        _ transform: @escaping (Output) async throws -> Future<T>
    ) -> Future<T> {
        .init { resumption, downstream in
            self(onStartup: resumption) { r in switch r {
                case .success(let a):
                    do {
                        _ = try await transform(a)(downstream).result
                    } catch {
                        await downstream(.failure(error))
                    }
                case let .failure(error):
                    await downstream(.failure(error))
            } }
        }
    }
}

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
