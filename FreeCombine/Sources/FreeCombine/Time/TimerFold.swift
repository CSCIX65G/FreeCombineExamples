//
//  TimerFold.swift
//  
//
//  Created by Van Simmons on 12/3/22.
//
import Atomics

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
extension Publisher {
    typealias TimerQueue = Queue<Publisher<Output>.Result>
    typealias TimerFold = AsyncFold<Void, Publisher<Output>.Result>

    func createTimerFold(
        downstreamIsSendable: ManagedAtomic<Bool>,
        queue: TimerQueue,
        downstream: @escaping Downstream
    ) async -> TimerFold {
        return await queue.fold(into: .init(
            initializer: { _ in },
            reducer: { _, r in
                if case .failure = (await Swift.Result { try await downstream(r) }) {
                    _ = downstreamIsSendable.exchange(false, ordering: .sequentiallyConsistent)
                    queue.finish()
                }
                return .none
            }
        ) )
    }
}

