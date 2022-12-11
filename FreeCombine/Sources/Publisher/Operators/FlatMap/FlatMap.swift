//
//  File.swift
//  
//
//  Created by Van Simmons on 12/10/22.
//
import Core

public extension Publisher {
    func flatMap<T>(
        _ transform: @escaping (Output) async -> Publisher<T>
    ) -> Publisher<T> {
        .init { resumption, downstream in self(onStartup: resumption) { r in switch r {
            case .value(let a):
                return try await transform(a)(flattener(downstream)).value
            case let .completion(value):
                return try await downstream(.completion(value))
        } } }
    }
}
