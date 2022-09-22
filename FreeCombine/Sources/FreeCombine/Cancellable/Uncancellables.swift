//
//  File.swift
//  
//
//  Created by Van Simmons on 9/20/22.
//
//
//  Cancellables.swift
//
//
//  Created by Van Simmons on 9/18/22.
//
import Atomics

extension Result where Failure == Swift.Error {
    func set(
        atomic: ManagedAtomic<UInt8>,
        to newStatus: Uncancellables.Status
    ) -> Self {
        .init {
            let (success, original) = atomic.compareExchange(
                expected: Uncancellables.Status.running.rawValue,
                desired: newStatus.rawValue,
                ordering: .sequentiallyConsistent
            )
            guard success else {
                switch original {
                    case Uncancellables.Status.finished.rawValue:
                        if case let .failure(error) = self { throw error }
                        throw Uncancellables.Error.alreadyCompleted
                    default:
                        throw Uncancellables.Error.internalInconsistency
                }
            }
            switch self {
                case let .success(value): return value
                case let .failure(error): throw error
            }
        }
    }
}

public enum Uncancellables {
    @TaskLocal static var status = ManagedAtomic<UInt8>(Status.running.rawValue)

    public enum Error: Swift.Error, Sendable {
        case alreadyCompleted
        case internalInconsistency
    }

    public enum Status: UInt8, Sendable, RawRepresentable, Equatable {
        case running
        case finished

        static func get(
            atomic: ManagedAtomic<UInt8>
        ) -> Status {
            let value = atomic.load(ordering: .sequentiallyConsistent)
            return .init(rawValue: value)!
        }
    }
}
