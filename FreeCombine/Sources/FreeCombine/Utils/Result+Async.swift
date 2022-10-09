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

public enum AtomicError<R: RawRepresentable>: Error {
    case failedTransition(from: R, to: R, current: R?)
}

public extension Result where Failure == Swift.Error {
    func set<R: RawRepresentable>(
        atomic: ManagedAtomic<R.RawValue>,
        from oldStatus: R,
        to newStatus: R
    ) throws -> Self where R.RawValue: AtomicValue {
        .init {
            let (success, original) = atomic.compareExchange(
                expected: oldStatus.rawValue,
                desired: newStatus.rawValue,
                ordering: .sequentiallyConsistent
            )
            guard success else {
                throw AtomicError.failedTransition(
                    from: oldStatus,
                    to: newStatus,
                    current: R(rawValue: original)
                )
            }
            return try get()
        }
    }
}
