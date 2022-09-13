//
//  AtomicBool.swift
//  
//
//  Created by Van Simmons on 9/12/22.
//

// This is stupid and done bc playgrounds can't do atomics
import Atomics

final class AtomicBool {
    actor Actor {
        weak var owner: AtomicBool?
        init(owner: AtomicBool?) {
            self.owner = owner
        }
        func store(_ value: Bool) {
            owner!.value = value
        }
        func load() -> Bool {
            owner!.value
        }
        func compareExchange(
            expected: Bool,
            desired: Bool
        ) async -> (exchanged: Bool, original: Bool) {
            guard owner!.value == expected else {
                return (false, owner!.value)
            }
            return (true, owner!.value)
        }
    }
    public private(set) var value: Bool
    fileprivate var actor: Actor? = .none
    fileprivate var atomic: ManagedAtomic<Bool>? = .none

    init(_ value: Bool) {
        self.value = value
        if FreeCombine.runningInPlayground {
            self.actor = .init(owner: self)
        } else {
            atomic = .init(value)
        }
    }

    // atomic.store(true, ordering: .sequentiallyConsistent)
    func store(_ value: Bool) async {
        guard atomic != nil else {
            await actor!.store(value)
            return
        }
        atomic!.store(true, ordering: .sequentiallyConsistent)
    }

    // deallocGuard.load(ordering: .sequentiallyConsistent)
    func load() async -> Bool {
        guard atomic != nil else { return await actor!.load() }
        return atomic!.load(ordering: .sequentiallyConsistent)
    }

    // atomic.compareExchange(expected: false, desired: true, ordering: .sequentiallyConsistent)
    func compareExchange(
        expected: Bool,
        desired: Bool
    ) async -> (exchanged: Bool, original: Bool) {
        guard atomic != nil else {
            return await actor!.compareExchange(
                expected: expected,
                desired: desired
            )
        }
        return atomic!.compareExchange(
            expected: false,
            desired: true,
            ordering: .sequentiallyConsistent
        )
    }
}
