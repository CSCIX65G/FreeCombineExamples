//
//  Publisher+TopLevelFunctions.swift
//  
//
//  Created by Van Simmons on 9/26/22.
//
func flattener<B>(
    _ downstream: @escaping Publisher<B>.Downstream
) -> Publisher<B>.Downstream {
    { b in switch b {
        case .completion(.finished):
            return .more
        case .value:
            return try await downstream(b)
        case .completion(.failure):
            return try await downstream(b)
    } }
}

func handleCancellation<Output>(
    of downstream: @escaping Publisher<Output>.Downstream
) async throws -> Publishers.Demand {
    _ = try await downstream(.completion(.failure(Publishers.Error.cancelled)))
    return .done
}
