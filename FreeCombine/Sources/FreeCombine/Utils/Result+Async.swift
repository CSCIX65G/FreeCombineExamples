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

    func tryMap<T>(
        _ transform: (Success) async throws -> T
    ) async -> Result<T, Swift.Error> {
        switch self {
            case let .success(r):
                do { return try await .success(transform(r)) }
                catch { return .failure(error) }
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

    func tryFlatMap<T>(
        _ transform: (Success) async throws -> Result<T, Swift.Error>
    ) async -> Result<T, Swift.Error> {
        switch self {
            case let .success(r):
                do { return try await transform(r) }
                catch { return .failure(error) }
            case let .failure(e): return .failure(e)
        }
    }

    func mapError<T: Swift.Error>(
        _ transform: (Failure) async -> T
    ) async -> Result<Success, T> {
        switch self {
            case let .success(r): return .success(r)
            case let .failure(e): return await .failure(transform(e))
        }
    }

    func tryMapError(
        _ transform: (Failure) async throws -> Swift.Error
    ) async -> Result<Success, Swift.Error> {
        switch self {
            case let .success(r): return .success(r)
            case let .failure(e):
                do { return try await .failure(transform(e)) }
                catch { return .failure(error) }
        }
    }

    func flatMapError<T: Swift.Error>(
        _ transform: (Failure) async -> Result<Success, T>
    ) async -> Result<Success, T> {
        switch self {
            case let .success(r): return .success(r)
            case let .failure(e): return await transform(e)
        }
    }

    func tryFlatMapError(
        _ transform: (Failure) async throws -> Result<Success, Swift.Error>
    ) async -> Result<Success, Swift.Error> {
        switch self {
            case let .success(r): return .success(r)
            case let .failure(e):
                do { return try await transform(e) }
                catch { return .failure(error) }
        }
    }
}
