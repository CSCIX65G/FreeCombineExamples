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
