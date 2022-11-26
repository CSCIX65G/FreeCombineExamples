//
//  Publisher+TopLevel.swift
//  
//
//  Created by Van Simmons on 9/26/22.
//
func flattener<T>(
    _ downstream: @escaping Publisher<T>.Downstream
) -> Publisher<T>.Downstream {
    { b in switch b {
        case .completion(.finished):
            return
        case .value:
            return try await downstream(b)
        case .completion(.failure):
            return try await downstream(b)
    } }
}

func handleCancellation<Output>(
    of downstream: @escaping Publisher<Output>.Downstream
) async throws -> Void {
    try await downstream(.completion(.failure(CancellationError())))
}
