//
//  AtomicOnce.swift
//
//
//  Created by Van Simmons on 2/18/23.
//

import Atomics

public struct Once<Value> {
    public let set: @Sendable (Value) throws -> Void
    public init() {
        set = ManagedAtomic<Box<Value>?>().set
    }
}

extension Once: Sendable where Value: Sendable { }

private extension ManagedAtomic {
    @Sendable convenience init<Once: Sendable>(once: Once.Type = Once.self) where Value == Box<Once>? {
        self.init(.none)
    }
}

private extension ManagedAtomic {
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
