//
//  AtomicOnce.swift
//
//
//  Created by Van Simmons on 2/18/23.
//

import Atomics

public typealias Once<Value: Sendable> = ManagedAtomic<Box<Value>?>

public extension ManagedAtomic {
    @Sendable convenience init<Once: Sendable>(once: Once.Type = Once.self) where Value == Box<Once>? {
        self.init(.none)
    }
}

public extension ManagedAtomic {
    @Sendable func set<Once: Sendable>(_ once: Once) throws -> Void where Value == Box<Once>? {
        let (success, newBox) = compareExchange(
            expected: .none,
            desired: .init(value: once),
            ordering: .releasing
        )
        guard success else {
            guard let newBox else { fatalError("Should have value") }
            throw AlreadyWrittenError(newBox.value)
        }
    }
}
