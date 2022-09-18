//
//  Map.swift
//
//
//  Created by Van Simmons on 9/18/22.
//
extension Future {
    public func map<T>(
        _ transform: @escaping (Output) async -> T
    ) -> Future<T> {
        .init { resumption, downstream in
            self(onStartup: resumption) { r in
                switch r {
                    case .success(let a):
                        return await downstream(.success(transform(a)))
                    case let .failure(error):
                        return await downstream(.failure(error))
                }
            }
        }
    }
}
