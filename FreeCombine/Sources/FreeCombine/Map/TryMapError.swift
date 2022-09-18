//
//  TryMapError.swift
//  
//
//  Created by Van Simmons on 9/18/22.
//
extension Future {
    public func tryMapError(
        _ transform: @escaping (Error) async throws -> Error
    ) -> Self {
        .init { resumption, downstream in
            self(onStartup: resumption) { r in
                switch r {
                    case .success(let a):
                        await downstream(.success(a))
                    case let .failure(tryError):
                        do { try await downstream(.failure(transform(tryError))) }
                        catch { await downstream(.failure(error)) }
                }
            }
        }
    }
}
