//
//  Uncancellable.swift
//
//
//  Created by Van Simmons on 9/7/22.
//
@_implementationOnly import Atomics

public final class Uncancellable<Output: Sendable> {
    private let task: Task<Output, Never>
    private let atomicStatus = ManagedAtomic<Bool>(false)

    public init(
        operation: @escaping @Sendable () async -> Output
    ) {
        let atomic = atomicStatus
        self.task = .init {
            let retValue = await operation()
            atomic.store(true, ordering: .sequentiallyConsistent)
            return retValue
        }
    }

    /*:
     [leaks of NIO EventLoopPromises](https://github.com/apple/swift-nio/blob/48916a49afedec69275b70893c773261fdd2cfde/Sources/NIOCore/EventLoopFuture.swift#L431)
     */
    deinit {
        guard hasFinished else {
            assertionFailure("ABORTING DUE TO LEAKED \(type(of: Self.self))")
            return
        }
    }

    public var hasFinished: Bool {
        atomicStatus.load(ordering: .sequentiallyConsistent)
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
