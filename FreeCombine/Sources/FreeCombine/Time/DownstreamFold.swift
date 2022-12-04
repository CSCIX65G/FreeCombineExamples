//
//  TimerFold.swift
//  
//
//  Created by Van Simmons on 12/3/22.
//
import Atomics

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
extension Publisher {
    struct DownstreamState { var errored: Error? }
    typealias DownstreamQueue = Queue<Publisher<Output>.Result>
    typealias DownstreamFold = AsyncFold<DownstreamState, Publisher<Output>.Result>

    static func check(_ isDispatchable: ManagedAtomic<Box<DownstreamState>>) throws -> Void {
        let dispatchError = isDispatchable.load(ordering: .sequentiallyConsistent).value.errored
        guard dispatchError == nil else { throw dispatchError! }
    }

    static func createDownstreamFold(
        _ isDispatchable: ManagedAtomic<Box<DownstreamState>>,
        _ queue: DownstreamQueue,
        _ downstream: @escaping Downstream
    ) async -> DownstreamFold {
        await queue.fold(into: .init(
            initializer: { _ in .init(errored: .none) },
            reducer: { state, r in
                guard state.errored == nil else { throw state.errored! }
                do { try await downstream(r) }
                catch { 
                    _ = isDispatchable.exchange(.init(value: .init(errored: error)), ordering: .sequentiallyConsistent)
                    state.errored = error
                    queue.finish()
                }
                return .none
            }
        ) )
    }

    static func createNextCancellable<C: Clock>(
        atomic: ManagedAtomic<Cancellable<Void>?>,
        clock: C,
        duration: C.Duration,
        queue: Queue<Publisher<Output>.Result>,
        dispatchValue: @escaping () -> Publisher<Output>.Result
    ) async -> Cancellable<Void>?  where C.Duration == Swift.Duration {
        await Timeout(clock: clock, after: duration).sink { result in
            guard atomic.exchange(.none, ordering: .sequentiallyConsistent) != nil,
                case .success = result,
                !Cancellables.isCancelled
            else { return }
            queue.continuation.yield(dispatchValue())
        }
    }
}

