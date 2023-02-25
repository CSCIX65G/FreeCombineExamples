//
//  TryFlatMap.swift
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
    func tryFlatMap<T: Sendable>(
        _ transform: @Sendable @escaping (Output) async throws -> Future<T>
    ) -> Future<T> {
        .init { resumption, downstream in
            self(onStartup: resumption) { r in switch r {
                case .success(let a):
                    do {
                        _ = try await transform(a)(downstream).result
                    } catch {
                        await downstream(.failure(error))
                    }
                case let .failure(error):
                    await downstream(.failure(error))
            } }
        }
    }
}
