//
//  ManagedAtomic+Update.swift
//  
//
//  Created by Van Simmons on 1/20/23.
//
import Atomics

enum ManagedAtomicActions {
    case skip
    case perform
    case fail
}

extension ManagedAtomic where Value: AtomicReference {
    func update(
        validate: (Value) throws -> Void,
        next: (Value) -> Value,
        performAfter: (Value) -> Void
    ) throws -> Void {
        var localValue = load(ordering: .relaxed)
        while true {
            try validate(localValue)
            let (success, newLocalValue) = compareExchange(
                expected: localValue,
                desired: next(localValue),
                ordering: .relaxed
            )
            guard !success else {
                performAfter(localValue)
                return
            }
            localValue = newLocalValue
        }
    }
}

