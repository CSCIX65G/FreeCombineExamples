//
//  Result+Async.swift
//  
//
//  Created by Van Simmons on 9/14/22.
//

extension Result {
    init(catching: () async throws -> Success) async where Failure == Swift.Error {
        do { self = try await .success(catching()) }
        catch { self = .failure(error) }
    }

    func map<T>(
        _ transform: (Success) async -> T
    ) async -> Result<T, Failure> {
        switch self {
            case let .success(r): return await .success(transform(r))
            case let .failure(e): return .failure(e)
        }
    }

    func flatMap<T>(
        _ transform: (Success) async -> Result<T, Failure>
    ) async -> Result<T, Failure> {
        switch self {
            case let .success(r): return await transform(r)
            case let .failure(e): return .failure(e)
        }
    }

    func mapError<T: Error>(
        _ transform: (Failure) async -> T
    ) async -> Result<Success, T> {
        switch self {
            case let .success(r): return .success(r)
            case let .failure(e): return await .failure(transform(e))
        }
    }

    func flatMapError<T>(
        _ transform: (Failure) async -> Result<Success, T>
    ) async -> Result<Success, T> {
        switch self {
            case let .success(r): return .success(r)
            case let .failure(e): return await transform(e)
        }
    }
}
