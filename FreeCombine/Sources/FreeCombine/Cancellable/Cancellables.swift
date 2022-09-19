//
//  Cancellables.swift
//  
//
//  Created by Van Simmons on 9/18/22.
//
import Atomics

public enum Cancellables {
    @TaskLocal static var status = ManagedAtomic<UInt8>(Status.running.rawValue)

    public static var isCancelled: Bool {
        status.load(ordering: .sequentiallyConsistent) == Status.cancelled.rawValue
    }

    public enum Error: Swift.Error, Sendable {
        case cancelled
        case alreadyCompleted
        case alreadyCancelled
        case alreadyFailed
        case internalInconsistency
    }

    public enum Status: UInt8, Sendable, RawRepresentable, Equatable {
        case running
        case finished
        case cancelled

        static func get(
            atomic: ManagedAtomic<UInt8>
        ) -> Status {
            let value = atomic.load(ordering: .sequentiallyConsistent)
            return .init(rawValue: value)!
        }
    }
}
