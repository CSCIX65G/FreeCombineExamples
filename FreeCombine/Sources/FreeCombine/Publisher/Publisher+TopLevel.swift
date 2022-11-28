//
//  Publisher+TopLevel.swift
//  
//
//  Created by Van Simmons on 9/26/22.
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
