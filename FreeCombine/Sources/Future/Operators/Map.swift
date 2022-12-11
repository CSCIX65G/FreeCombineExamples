//
//  File.swift
//  
//
//  Created by Van Simmons on 12/10/22.
//

import Core

extension Future {
    public func map<T>(
        _ transform: @escaping (Output) async -> T
    ) -> Future<T> {
        .init { resumption, downstream in
            self(onStartup: resumption) { r in
                switch r {
                    case .success(let a):
                        await downstream(.success(transform(a)))
                    case let .failure(error):
                        await downstream(.failure(error))
                }
            }
        }
    }
}
