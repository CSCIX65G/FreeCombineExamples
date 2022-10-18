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

public extension Result where Failure == Swift.Error {
    func set<R: AtomicValue>(
        atomic: ManagedAtomic<R>,
        from oldStatus: R,
        to newStatus: R
    ) -> Self {
        .init {
            let (success, original) = atomic.compareExchange(
                expected: oldStatus,
                desired: newStatus,
                ordering: .sequentiallyConsistent
            )
            guard success else {
                throw AtomicError.failedTransition(
                    from: oldStatus,
                    to: newStatus,
                    current: original
                )
            }
            return try get()
        }
    }
}
