//
//  AsyncCounter.swift
//  
//
//  Created by Van Simmons on 1/17/23.
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
    public func increment(by: Int = 1) -> Int {
        atomicValue.wrappingIncrementThenLoad(by: by, ordering: .relaxed)
    }

    public var incremented: Int {
        atomicValue.wrappingIncrementThenLoad(ordering: .relaxed)
    }

    @discardableResult
    public func decrement(by: Int = 1) -> Int {
        atomicValue.wrappingDecrementThenLoad(by: by, ordering: .relaxed)
    }

    public var decremented: Int {
        atomicValue.wrappingDecrementThenLoad(ordering: .relaxed)
    }
}
