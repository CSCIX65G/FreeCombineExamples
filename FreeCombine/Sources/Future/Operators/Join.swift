//
//  File.swift
//  
//
//  Created by Van Simmons on 12/10/22.
//
import Core

public extension Future {
    func join<T>() -> Future<T> where Output == Future<T> {
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
