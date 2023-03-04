//
//  Result+Async.swift
//  
//
//  Created by Van Simmons on 9/14/22.
//
//  Copyright 2022, ComputeCycles, LLC
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//
import Atomics

public enum AsyncResult<Success, Failure: Error> {
    case success(Success)
    case failure(Failure)
}

extension AsyncResult: Sendable where Success: Sendable { }

public extension AsyncResult {
    init(_ result: Result<Success, Failure>) {
        switch result {
            case let .success(value): self = .success(value)
            case let .failure(error): self = .failure(error)
        }
    }

    init(catching: () async throws -> Success) async where Failure == Swift.Error {
        do { self = try await .success(catching()) }
        catch { self = .failure(error) }
    }

    init(catching: () throws -> Success) where Failure == Swift.Error {
        do { self = try .success(catching()) }
        catch { self = .failure(error) }
    }

    var result: Result<Success, Failure> {
        switch self {
            case let .success(value): return .success(value)
            case let .failure(error): return .failure(error)
        }
    }

    func get() throws -> Success {
        switch self {
            case let .success(value): return value
            case let .failure(error): throw error
        }
    }

    func map<NewSuccess>(
        _ transform: (Success) -> NewSuccess
    ) -> AsyncResult<NewSuccess, Failure> {
        switch self {
            case let .success(value): return .success(transform(value))
            case let .failure(error): return .failure(error)
        }
    }

    func flatMap<NewSuccess>(
        _ transform: (Success) -> AsyncResult<NewSuccess, Failure>
    ) -> AsyncResult<NewSuccess, Failure> {
        switch self {
            case let .success(value): return transform(value)
            case let .failure(error): return .failure(error)
        }
    }

    func mapError<NewFailure>(
        _ transform: (Failure) -> NewFailure
    ) -> AsyncResult<Success, NewFailure> {
        switch self {
            case let .success(value): return .success(value)
            case let .failure(error): return .failure(transform(error))
        }
    }

    func flatMapError<NewFailure>(
        _ transform: (Failure) async -> AsyncResult<Success, NewFailure>
    ) async -> AsyncResult<Success, NewFailure> {
        switch self {
            case let .success(value): return .success(value)
            case let .failure(error): return await transform(error)
        }
    }
}

public extension Result {
    init(_ asyncResult: AsyncResult<Success, Failure>) {
        switch asyncResult {
            case let .success(value): self = .success(value)
            case let .failure(error): self = .failure(error)
        }
    }
    var asyncResult: AsyncResult<Success, Failure> { .init(self) }
}
