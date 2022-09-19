//
//  FlatMapError.swift
//  
//
//  Created by Van Simmons on 9/18/22.
//
extension Future {
    func flatMapError(
        _ transform: @escaping (Error) async -> Self
    ) -> Self {
        .init { resumption, downstream in
            self(onStartup: resumption) { r in switch r {
                case .success:
                    await downstream(r)
                case let .failure(error):
                    _ = await transform(error)(downstream).result
            } }
        }
    }
}
