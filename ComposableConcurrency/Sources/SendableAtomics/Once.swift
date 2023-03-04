//
//  AtomicOnce.swift
//
//
//  Created by Van Simmons on 2/18/23.
//

import Atomics

public final class OnceReference<Once: Sendable>: AtomicReference, Sendable {
    public let once: Once
    public init(once: Once) {
        self.once = once
    }
}

public typealias Once<Value: Sendable> = ManagedAtomic<OnceReference<Value>?>

public extension ManagedAtomic {
    @Sendable convenience init<Once: Sendable>(once: Once.Type = Once.self) where Value == OnceReference<Once>? {
        self.init(.none)
    }
}

public extension ManagedAtomic {
    @Sendable func set<Once: Sendable>(_ once: Once) throws -> Void where Value == OnceReference<Once>? {
        let (success, newOnce) = compareExchange(
            expected: .none,
            desired: .init(once: once),
            ordering: .releasing
        )
        guard success else {
            guard let newOnce else { fatalError("Should have value") }
            throw AlreadyWrittenError(newOnce.once)
        }
    }
}
