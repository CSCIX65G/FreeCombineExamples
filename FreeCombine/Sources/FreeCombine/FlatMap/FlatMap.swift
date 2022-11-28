//
//  FlatMap.swift
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
    func flatMap<T>(
        _ transform: @escaping (Output) async -> Future<T>
    ) -> Future<T> {
        .init { resumption, downstream in self(onStartup: resumption) { r in switch r {
            case .success(let a):
                _ = await transform(a)(downstream).result
            case let .failure(error):
                await downstream(.failure(error))
        } } }
    }
}

public extension Publisher {
    func flatMap<T>(
        _ transform: @escaping (Output) async -> Publisher<T>
    ) -> Publisher<T> {
        .init { resumption, downstream in self(onStartup: resumption) { r in switch r {
            case .value(let a):
                return try await transform(a)(flattener(downstream)).value
            case let .completion(value):
                return try await downstream(.completion(value))
        } } }
    }
}

public extension Cancellable {
    func flatMap<T>(
        _ transform: @escaping (Output) async -> Cancellable<T>
    ) -> Cancellable<T> {
        map(transform).join()
    }
}

extension Uncancellable {
    public func flatMap<T>(
        _ transform: @escaping (Output) async -> Uncancellable<T>
    ) -> Uncancellable<T> {
        map(transform).join()
    }
}

extension AsyncFunc {
    public func flatMap<T>(
        _ transform: @escaping (R) async throws -> AsyncFunc<A, T>
    ) -> AsyncFunc<A, T> {
        .init { a in try await transform(call(a))(a) }
    }
}

public extension AsyncContinuation {
    func flatMap<T>(
        _ transform: @escaping (Output) async -> AsyncContinuation<T, Return>
    ) -> AsyncContinuation<T, Return> {
        .init { resumption, downstream in
            self(onStartup: resumption) { a in
                try await transform(a)(downstream).value
            }
        }
    }
}
