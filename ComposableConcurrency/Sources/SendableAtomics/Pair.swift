//
//  AtomicPair.swift
//  
//
//  Created by Van Simmons on 2/18/23.
//

import Atomics

public struct Pair<Left, Right> {
    public let setLeft: @Sendable (Left) throws -> (Left, Right)?
    public let setRight: @Sendable (Right) throws -> (Left, Right)?
    public init(left: Left? = .none, right: Right? = .none) {
        let atomic = ManagedAtomic(left: left, right: right)
        setLeft = atomic.setLeft
        setRight = atomic.setRight
    }

    @inlinable @Sendable public func set(left: Left) throws -> (Left, Right)? { try setLeft(left) }
    @inlinable @Sendable public func set(right: Right) throws -> (Left, Right)? { try setRight(right) }
}

extension Pair: Sendable where Left: Sendable, Right: Sendable { }

private extension ManagedAtomic {
    @Sendable convenience init<Left: Sendable, Right: Sendable> (
        left: Left? = .none,
        right: Right? = .none
    ) where Value == Box<(left: Left?, right: Right?)> {
        self.init(Box(value: (left: left, right: right)))
    }
}

private extension ManagedAtomic {
    @Sendable func setLeft<
        Left: Sendable,
        Right: Sendable
    >(_ lValue: Left) throws -> (Left, Right)? where Value == Box<(left: Left?, right: Right?)> {
        let current = load(ordering: .acquiring)
        guard current.value.left == nil else { throw AlreadyWrittenError(Either<Left, Right>.left(current.value.left!)) }
        let (success, newCurrent) = compareExchange(
            expected: current,
            desired: .init(value: (left: lValue, right: current.value.right)),
            ordering: .releasing
        )
        guard !success else {
            guard let rValue = newCurrent.value.right else { return .none }
            return (lValue, rValue)
        }
        return try setLeft(lValue)
    }

    @Sendable func setRight<
        Left: Sendable,
        Right: Sendable
    >(_ rValue: Right) throws -> (Left, Right)? where Value == Box<(left: Left?, right: Right?)> {
        let current = load(ordering: .acquiring)
        guard current.value.right == nil else { throw AlreadyWrittenError(Either<Left, Right>.right(current.value.right!)) }
        let (success, newCurrent) = compareExchange(
            expected: current,
            desired: .init(value: (left: current.value.left, right: rValue)),
            ordering: .releasing
        )
        guard !success else {
            guard let lValue = newCurrent.value.left else { return .none }
            return (lValue, rValue)
        }
        return try setRight(rValue)
    }
}
