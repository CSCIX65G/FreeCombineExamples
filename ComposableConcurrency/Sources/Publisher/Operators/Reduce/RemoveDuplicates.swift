//
//  RemoveDuplicates.swift
//
//
//  Created by Van Simmons on 5/23/22.
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
class Deduplicator<A: Sendable>: @unchecked Sendable {
    let isEquivalent: (A, A) async -> Bool
    var currentValue: A!

    init(_ predicate: @escaping (A, A) async -> Bool) {
        self.isEquivalent = predicate
    }

    func forward(
        value: A,
        with downstream: (Publisher<A>.Result) async throws -> Void
    ) async throws -> Void {
        guard let current = currentValue else {
            currentValue = value
            return try await downstream(.value(value))
        }
        guard !(await isEquivalent(value, current)) else { return }
        currentValue = value
        return try await downstream(.value(value))
    }
}

extension Publisher where Output: Equatable {
    func removeDuplicates() -> Publisher<Output> {
        let sendableEquality: @Sendable (Output, Output) -> Bool = { lhs, rhs in lhs == rhs }
        return removeDuplicates(by: sendableEquality)
    }
}

extension Publisher {
    func removeDuplicates(
        by predicate: @Sendable @escaping (Output, Output) async -> Bool
    ) -> Publisher<Output> {
        .init { resumption, downstream in
            let deduplicator = Deduplicator<Output>(predicate)
            return self(onStartup: resumption) { r in
                guard !Task.isCancelled else {
                    return try await handleCancellation(of: downstream)
                }
                switch r {
                    case .value(let a):
                        return try await deduplicator.forward(value: a, with: downstream)
                    case .completion(.failure(let e)):
                        return try await downstream(.completion(.failure(e)))
                    case .completion(.finished):
                        return try await downstream(r)
                }
            }
        }
    }
}
