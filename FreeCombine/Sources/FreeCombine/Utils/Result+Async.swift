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

extension Result {
    init(catching: () async throws -> Success) async where Failure == Swift.Error {
        do { self = try await .success(catching()) }
        catch { self = .failure(error) }
    }
}

public extension Result where Failure == Swift.Error {
    func set<R: AtomicValue>(
        atomic: ManagedAtomic<R>,
        from oldStatus: R,
        to newStatus: R
    ) -> Self {
        .init {
            let (success, original) = atomic.compareExchange(
                expected: oldStatus,
                desired: newStatus,
                ordering: .sequentiallyConsistent
            )
            guard success else {
                throw AtomicError.failedTransition(
                    from: oldStatus,
                    to: newStatus,
                    current: original
                )
            }
            return try get()
        }
    }
}
