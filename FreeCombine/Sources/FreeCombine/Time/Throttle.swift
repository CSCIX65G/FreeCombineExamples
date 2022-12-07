//
//  Throttle.swift
//  
//
//  Created by Van Simmons on 12/3/22.
//
import Atomics
import Channel
import Core

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
            let instantBox = MutableBox<C.Instant?>.init(value: .none)
            return self(onStartup: resumption) { r in
                guard case .value = r else {
                    return try await downstream(r)
                }
                if let lastInstant = instantBox.value {
                    if lastInstant.advanced(by: duration) < clock.now {
                        instantBox.set(value: clock.now)
                        return try await downstream(r)
                    } else {
                        return
                    }
                }
                instantBox.set(value: clock.now)
                return try await downstream(r)
            }
        }
    }

    private func throttleLast<C: Clock>(
        clock: C,
        interval duration: Swift.Duration
    ) -> Self where C.Duration == Swift.Duration {
        .init { resumption, downstream in
            let isDispatchable = ManagedAtomic<Box<DownstreamState>>.init(.init(value: .init()))
            let queue = Queue<(C.Instant, Publisher<Output>.Result)>(buffering: .bufferingNewest(1))
            let sender: MutableBox<Cancellable<Void>?> = .init(value: .none)
            return self(onStartup: resumption) { r in
                try await Self.check(isDispatchable, sender.value)
                if sender.value == nil {
                    let _: Void = try await pause { resumption in
                        sender.set(value: .init {
                            resumption.resume()
                            for await pair in queue.stream {
                                let (then, r) = pair
                                do { try await downstream(r) }
                                catch {
                                    _ = isDispatchable.exchange(.init(value: .init(errored: error)), ordering: .sequentiallyConsistent)
                                    queue.finish()
                                }
                                try await clock.sleep(until: then.advanced(by: duration), tolerance: .none)
                            }
                            switch isDispatchable.load(ordering: .sequentiallyConsistent).value.errored {
                                case let .some(error): throw error
                                case .none: return
                            }
                        })
                    }
                }
                if case .terminated = queue.yield((clock.now, r)) {
                    _ = try await sender.value?.value
                    return
                }
                if case .completion = r {
                    queue.finish()
                    try await sender.value?.value
                    return
                }
            }
        }
    }
}
