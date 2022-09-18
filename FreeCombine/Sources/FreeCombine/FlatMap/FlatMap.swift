//
//  FlatMap.swift
//  
//
//  Created by Van Simmons on 9/18/22.
//
extension Future {
    func flatMap<T>(
        _ transform: @escaping (Output) async -> Future<T>
    ) -> Future<T> {
        .init { resumption, downstream in
            self(onStartup: resumption) { r in switch r {
                case .success(let a):
                    _ = await transform(a)(downstream).result
                case let .failure(error):
                    await downstream(.failure(error))
            } }
        }
    }
}
