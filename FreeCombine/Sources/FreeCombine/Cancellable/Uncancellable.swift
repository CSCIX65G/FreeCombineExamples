//
//  Uncancellable.swift
//
//
//  Created by Van Simmons on 9/7/22.
//
@preconcurrency import Atomics

public final class Uncancellable<Output: Sendable>: Sendable {
    private let task: Task<Output, Never>
    private let deallocGuard = ManagedAtomic<Bool>(false)

    public init(
        operation: @escaping @Sendable () async -> Output
    ) {
        let atomic = deallocGuard
        self.task = .init {
            let retValue = await operation()
            atomic.store(true, ordering: .sequentiallyConsistent)
            return retValue
        }
    }

    deinit {
        guard isCompleting else {
            assertionFailure("ABORTING DUE TO LEAKED \(type(of: Self.self))")
            return
        }
    }

    public var isCompleting: Bool {
        deallocGuard.load(ordering: .sequentiallyConsistent)
    }

    public var value: Output {
        get async {
            await task.value
        }
    }
}

extension Uncancellable {
    public func map<T>(
        _ transform: @escaping (Output) async -> T
    ) -> Uncancellable<T> {
        .init { await transform(self.value) }
    }

    public func join<T>() -> Uncancellable<T> where Output == Uncancellable<T> {
        .init { await self.value.value }
    }

    public func flatMap<T>(
        _ transform: @escaping (Output) async -> Uncancellable<T>
    ) -> Uncancellable<T> {
        map(transform).join()
    }
}

func zip<Left, Right>(
    _ left: Uncancellable<Left>,
    _ right: Uncancellable<Right>
) -> Uncancellable<(Left, Right)> {
    .init {
        async let l = await left.value
        async let r = await right.value
        return await (l, r)
    }
}
