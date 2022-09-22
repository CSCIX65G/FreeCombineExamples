//
//  Result+Async.swift
//  
//
//  Created by Van Simmons on 9/14/22.
//
import Atomics

extension Result {
    init(catching: () async throws -> Success) async where Failure == Swift.Error {
        do { self = try await .success(catching()) }
        catch { self = .failure(error) }
    }
}

extension Result where Failure == Swift.Error {
    func set<R: RawRepresentable>(
        atomic: ManagedAtomic<UInt8>,
        from oldStatus: R,
        to newStatus: R
    ) throws -> Self where R.RawValue == UInt8 {
        .init {
            let (success, original) = atomic.compareExchange(
                expected: oldStatus.rawValue,
                desired: newStatus.rawValue,
                ordering: .sequentiallyConsistent
            )
            guard success else {
                switch original {
                    case Cancellables.Status.cancelled.rawValue:
                        if case let .failure(error) = self { throw error }
                        throw Cancellables.Error.alreadyCancelled
                    default:
                        throw Cancellables.Error.internalInconsistency
                }
            }
            return try get()
        }
    }
}
