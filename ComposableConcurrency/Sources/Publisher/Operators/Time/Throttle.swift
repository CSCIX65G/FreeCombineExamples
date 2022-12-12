//
//  Throttle.swift
//  
//
//  Created by Van Simmons on 12/3/22.
//
import Atomics
import Channel
import Core
import Queue

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
extension Publisher {
    func throttle<C: Clock>(
        clock: C,
        interval duration: Swift.Duration,
        latest: Bool = false
    ) -> Self where C.Duration == Swift.Duration {
        latest
        ? throttleLast(clock: clock, interval: duration)
        : throttleFirst(clock: clock, interval: duration)
    }

    private func throttleFirst<C: Clock>(
        clock: C,
        interval duration: Swift.Duration
    ) -> Self where C.Duration == Swift.Duration {
        .init { resumption, downstream in
            let instantBox = MutableBox<C.Instant>.init(value: clock.now.advanced(by: duration * -1.0))
            return self(onStartup: resumption) { r in
                let thisInstant = clock.now
                guard case .value = r else {
                    return try await downstream(r)
                }
                if thisInstant >= instantBox.value.advanced(by: duration) {
                    instantBox.set(value: clock.now)
                    try await downstream(r)
                    instantBox.set(value: thisInstant)
                }
            }
        }
    }

    private func throttleHandler<C: Clock>(
        resumption: Resumption<Void>,
        clock: C,
        duration: C.Duration,
        downstream: @escaping Downstream,
        isDispatchable: ManagedAtomic<Box<DownstreamState>>,
        atomicValue: ManagedAtomic<Box<Output>?>,
        queue: Queue<C.Instant>
    ) -> @Sendable () async throws -> Void where C.Duration == Swift.Duration {
        {
            resumption.resume()
            for await then in queue.stream {
                while true {
                    do {
                        try await clock.sleep(until: then.advanced(by: duration), tolerance: .none)
                        guard let toSend = atomicValue.exchange(.none, ordering: .sequentiallyConsistent)?.value else {
                            break
                        }
                        try await downstream(.value(toSend))
                    }
                    catch {
                        _ = isDispatchable.exchange(.init(value: .init(errored: error)), ordering: .sequentiallyConsistent)
                        queue.finish()
                        for await _ in queue.stream {
                            _ = atomicValue.exchange(.none, ordering: .sequentiallyConsistent)?.value
                        }
                        return
                    }
                }
            }
        }
    }
    
    private func throttleLast<C: Clock>(
        clock: C,
        interval duration: Swift.Duration
    ) -> Self where C.Duration == Swift.Duration {
        .init { resumption, downstream in
            let isDispatchable = ManagedAtomic<Box<DownstreamState>>.init(.init(value: .init()))
            let queue = Queue<C.Instant>(buffering: .bufferingNewest(1))
            let sender: MutableBox<Cancellable<Void>?> = .init(value: .none)
            let atomicValue: ManagedAtomic<Box<Output>?> = .init(.none)

            return self(onStartup: resumption) { r in
                let thisInstant = clock.now
                try await Self.check(isDispatchable, sender.value)
                if sender.value == nil {
                    let _: Void = try await pause { resumption in
                        sender.set(
                            value: .init(
                                operation: throttleHandler(
                                    resumption: resumption,
                                    clock: clock,
                                    duration: duration,
                                    downstream: downstream,
                                    isDispatchable: isDispatchable,
                                    atomicValue: atomicValue,
                                    queue: queue
                                )
                            )
                        )
                    }
                }
                switch r {
                    case .completion:
                        _ = try? queue.tryYield(thisInstant)
                        queue.finish()
                        try await sender.value?.value ?? ()
                        return try await downstream(r)
                    case let .value(value):
                        _ = atomicValue.exchange(.init(value:(value)), ordering: .sequentiallyConsistent)
                        guard case .terminated = queue.yield(thisInstant) else {
                            return
                        }
                        try await sender.value?.value ?? ()
                        throw isDispatchable.load(ordering: .sequentiallyConsistent).value.errored ?? FinishedError()
                }
            }
        }
    }
}
