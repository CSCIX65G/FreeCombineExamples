//
//  TryMap.swift
//
//
//  Created by Van Simmons on 9/18/22.
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
extension Future {
    func tryMap<T>(
        _ transform: @escaping (Output) async throws -> T
    ) -> Future<T> {
        .init { resumption, downstream in
            self(onStartup: resumption) { r in
                switch r {
                    case .success(let a):
                        do { return try await downstream(.success(transform(a))) } catch {
                            return await downstream(.failure(error))
                        }
                    case let .failure(error):
                        return await downstream(.failure(error))
                }
            }
        }
    }
}

public extension AsyncContinuation {
    func tryMap<T>(
        _ transform: @escaping (Output) async throws -> T
    ) -> AsyncContinuation<T, Return> {
        .init { resumption, downstream in
            self(onStartup: resumption) { a in
                try await downstream(transform(a))
            }
        }
    }
}


