//
//  MapError.swift
//  
//
//  Created by Van Simmons on 9/18/22.
//
extension Future {
    public func mapError(
        _ transform: @escaping (Error) async -> Error
    ) -> Self {
        .init { resumption, downstream in
            self(onStartup: resumption) { r in
                switch r {
                    case .success:
                        await downstream(r)
                    case let .failure(error):
                        await downstream(.failure(transform(error)))
                }
            }
        }
    }
}
