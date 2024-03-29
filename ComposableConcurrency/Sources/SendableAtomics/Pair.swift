//
//  AtomicPair.swift
//  
//
//  Created by Van Simmons on 2/18/23.
//

import Atomics

public final class PairBox<Left, Right> {
    fileprivate let left: Left?
    fileprivate let right: Right?

    var pair: (Left, Right)? {
        guard let l = left, let r = right else { return .none }
        return (l, r)
    }

    public init(left: Left? = .none, right: Right? = .none) {
        self.left = left
        self.right = right
    }
}

extension PairBox: Sendable where Left: Sendable, Right: Sendable { }
extension PairBox: AtomicReference { }

public typealias Pair<Left: Sendable, Right: Sendable> = ManagedAtomic<PairBox<Left, Right>>

public extension ManagedAtomic {
    @Sendable convenience init<Left: Sendable, Right: Sendable> (
        left: Left? = .none,
        right: Right? = .none
    ) where Value == PairBox<Left, Right> {
        self.init(PairBox(left: left, right: right))
    }
}

public extension ManagedAtomic {
    @Sendable func setLeft<
        Left: Sendable,
        Right: Sendable
    >(_ lValue: Left) throws -> (Left, Right)? where Value == PairBox<Left, Right> {
        let current = load(ordering: .acquiring)
        guard current.left == nil else { throw AlreadyWrittenError(Either<Left, Right>.left(current.left!)) }
        let (success, newCurrent) = compareExchange(
            expected: current,
            desired: .init(left: lValue, right: current.right),
            ordering: .releasing
        )
        guard !success else {
            guard let rValue = newCurrent.right else { return .none }
            return (lValue, rValue)
        }
        return try setLeft(lValue)
    }

    @Sendable func setRight<
        Left: Sendable,
        Right: Sendable
    >(_ rValue: Right) throws -> (Left, Right)? where Value == PairBox<Left, Right> {
        let current = load(ordering: .acquiring)
        guard current.right == nil else { throw AlreadyWrittenError(Either<Left, Right>.right(current.right!)) }
        let (success, newCurrent) = compareExchange(
            expected: current,
            desired: .init(left: current.left, right: rValue),
            ordering: .releasing
        )
        guard !success else {
            guard let lValue = newCurrent.left else { return .none }
            return (lValue, rValue)
        }
        return try setRight(rValue)
    }
}
