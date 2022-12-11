//
//  File.swift
//  
//
//  Created by Van Simmons on 12/10/22.
//
import Core

public extension Publisher {
    func map<T>(
        _ transform: @escaping (Output) async -> T
    ) -> Publisher<T> {
        .init { resumption, downstream in
            self(onStartup: resumption) { r in switch r {
                case .value(let a):
                    let b = await transform(a)
                    try Cancellables.checkCancellation()
                    return try await downstream(.value(b))
                case let .completion(value):
                    return try await downstream(.completion(value))
            } }
        }
    }
}
