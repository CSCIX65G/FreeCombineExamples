//
//  TryMap.swift
//
//
//  Created by Van Simmons on 9/18/22.
//
extension Future {
    func tryMap<T>(
        _ transform: @escaping (Output) async throws -> T
    ) -> Future<T> {
        .init { resumption, downstream in
            self(onStartup: resumption) { r in
                switch r {
                    case .success(let a):
                        do { return try await downstream(.success(transform(a))) } catch {
                            return await downstream(.failure(error))
                        }
                    case let .failure(error):
                        return await downstream(.failure(error))
                }
            }
        }
    }
}
