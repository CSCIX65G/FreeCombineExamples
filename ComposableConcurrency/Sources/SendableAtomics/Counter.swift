//
//  AsyncCounter.swift
//  
//
//  Created by Van Simmons on 1/17/23.
//
import Atomics

public struct Counter: Sendable {
    public let increment: @Sendable (Int) -> Int
    public let decrement: @Sendable (Int) -> Int
    public let current: @Sendable () -> Int

    public init(startingValue: Int = 0) {
        let underlying = _Counter(count: startingValue)
        self.increment = underlying.increment(by:)
        self.decrement = underlying.decrement(by:)
        self.current = { underlying.count }
    }

    @inlinable
    public var count: Int { current() }

    @inlinable
    @discardableResult
    @Sendable public func increment(by: Int = 1) -> Int { increment(by) }

    @inlinable
    @discardableResult
    @Sendable public func decrement(by: Int = 1) -> Int { decrement(by) }
}

private struct _Counter {
    private let atomicValue: ManagedAtomic<Int>

    @usableFromInline
    init(count: Int = 0) {
        self.atomicValue = .init(count)
    }

    @usableFromInline
    var count: Int {
        atomicValue.load(ordering: .relaxed)
    }

    @usableFromInline
    @discardableResult
    @Sendable func increment(by: Int = 1) -> Int {
        atomicValue.wrappingIncrementThenLoad(by: by, ordering: .relaxed)
    }

    @usableFromInline
    var incremented: Int {
        atomicValue.wrappingIncrementThenLoad(ordering: .relaxed)
    }

    @usableFromInline
    @discardableResult
    @Sendable func decrement(by: Int = 1) -> Int {
        atomicValue.wrappingDecrementThenLoad(by: by, ordering: .relaxed)
    }

    @usableFromInline
    var decremented: Int {
        atomicValue.wrappingDecrementThenLoad(ordering: .relaxed)
    }
}
