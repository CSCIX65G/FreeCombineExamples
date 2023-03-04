//
//  TimerFold.swift
//  
//
//  Created by Van Simmons on 12/3/22.
//
import Atomics
import Core
import SendableAtomics

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
extension Publisher {
    struct DownstreamState { var errored: Error? }

    static func check(
        _ isDispatchable: ManagedAtomic<Box<DownstreamState>>,
        _ cancellable: Cancellable<Void>? = .none
    ) async throws -> Void {
        let dispatchError = isDispatchable.load(ordering: .relaxed).value.errored
        guard dispatchError == nil else {
            try await cancellable?.value
            throw dispatchError!
        }
    }
}

