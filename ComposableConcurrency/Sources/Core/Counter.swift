//
//  Counter.swift
//
//
//  Created by Van Simmons on 3/1/22.
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

public struct Counter {
    private let atomicValue: ManagedAtomic<Int>

    public init(count: Int = 0) {
        self.atomicValue = .init(count)
    }

    public var count: Int {
        atomicValue.load(ordering: .relaxed)
    }

    @discardableResult
    @Sendable public func increment(by: Int = 1) -> Int {
        atomicValue.wrappingIncrementThenLoad(by: by, ordering: .relaxed)
    }

    public var incremented: Int {
        atomicValue.wrappingIncrementThenLoad(ordering: .relaxed)
    }

    @discardableResult
    @Sendable public func decrement(by: Int = 1) -> Int {
        atomicValue.wrappingDecrementThenLoad(by: by, ordering: .relaxed)
    }

    public var decremented: Int {
        atomicValue.wrappingDecrementThenLoad(ordering: .relaxed)
    }
}
