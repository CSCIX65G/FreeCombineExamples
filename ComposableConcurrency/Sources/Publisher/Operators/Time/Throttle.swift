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
    public struct Throttler<C: Clock>: Sendable where C.Duration: Sendable {
        let duration: C.Duration
        let downstream: Downstream
        let downstreamState: ManagedAtomic<Box<DownstreamState>>
        let downstreamValue: ManagedAtomic<Box<Array<(instant: C.Instant, value: Output)>>?>
        let queue: Queue<Void>
        private(set) var sender: Cancellable<Void>!

        init(
            clock: C,
            duration: C.Duration,
            downstream: @escaping Downstream,
            downstreamState: ManagedAtomic<Box<DownstreamState>> = .init(.init(value: .init())),
            downstreamValue: ManagedAtomic<Box<Array<(instant: C.Instant, value: Output)>>?> = .init(.none),
            queue: Queue<Void> = .init(buffering: .bufferingNewest(1))
        ) async {
            self.duration = duration
            self.downstream = downstream
            self.downstreamState = downstreamState
            self.downstreamValue = downstreamValue
            self.queue = queue
            let downstreamSender = Self.downstreamSender(downstream: downstream, downstreamState: downstreamState, queue: queue)
            await unfailingPause { resumption in
                self.sender = .init {
                    var referenceInstant: C.Instant? = .none
                    try resumption.resume()
                    var arr: Array<(instant: C.Instant, value: Output)> = .init()
                    for await _ in queue.stream {
                        while let next = downstreamValue.exchange(.none, ordering: .sequentiallyConsistent)?.value {
                            arr = arr + next
                            if referenceInstant == nil { referenceInstant = arr.first!.instant }
                            for i in 0 ..< arr.count - 1 {
                                if referenceInstant!.duration(to: arr[i].instant) > duration {
                                    try await downstreamSender(arr[i].value)
                                    referenceInstant = arr[i].instant
                                }
                            }
                            guard clock.now < arr.last!.instant.advanced(by: duration) else {
                                try await downstreamSender(arr.last!.value)
                                arr = []
                                referenceInstant = .none
                                break
                            }
                            try await clock.sleep(until: referenceInstant!.advanced(by: duration), tolerance: .none)
                            arr = [arr.last!]
                        }
                        guard let _ = arr.last?.value else {
                            referenceInstant = .none
                            continue
                        }
                        try await downstreamSender(arr.last!.value)
                    }
                    guard arr.count > 0 else { return }
                    for i in 0 ..< arr.count - 1 {
                        if referenceInstant!.duration(to: arr[i].instant) > duration {
                            try await downstreamSender(arr[i].value)
                            referenceInstant = arr[i].instant
                        }
                    }
                    if let last = arr.last {
                        try await downstreamSender(last.value)
                    }
                }
            }
        }

        @Sendable static func downstreamSender(
            downstream: @escaping Downstream,
            downstreamState: ManagedAtomic<Box<DownstreamState>> = .init(.init(value: .init())),
            queue: Queue<Void> = .init(buffering: .bufferingNewest(1))
        ) -> @Sendable (Output) async throws -> Void {
            { value in
                do { try await downstream(.value(value)) }
                catch {
                    _ = downstreamState.exchange(.init(value: .init(errored: error)), ordering: .sequentiallyConsistent)
                    queue.finish()
                    for await _ in queue.stream { }
                    throw error
                }
            }
        }

        func send(_ now: C.Instant, _ value: Output) throws -> Void {
            let current = downstreamValue.load(ordering: .sequentiallyConsistent)
            let new = (current?.value ?? [(instant: C.Instant, value: Output)]()) + [(instant: now, value: value)]
            let (success, replaced) = downstreamValue.compareExchange(
                expected: current,
                desired: .init(value: new),
                ordering: .sequentiallyConsistent
            )
            if !success {
                guard replaced == nil else { fatalError("can only have nil") }
                let box = Box(value:  [(instant: now, value: value)])
                guard downstreamValue.exchange(box, ordering: .sequentiallyConsistent) == nil else {
                    fatalError("really, this can only be nil")
                }
            }
            guard case .terminated = queue.yield() else { return }
            throw FinishedError()
        }

        func complete(with completion: Completion) async throws -> Void {
            _ = try? queue.tryYield()
            queue.finish()
            try await sender.value
            return try await downstream(.completion(completion))
        }
    }

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

    private func throttleLast<C: Clock>(
        clock: C,
        interval duration: Swift.Duration
    ) -> Self where C.Duration == Swift.Duration {
        .init { resumption, downstream in
            let throttleBox: MutableBox<Throttler<C>?> = .init(value: .none)
            return self(onStartup: resumption) { r in
                if throttleBox.value == nil {
                    await throttleBox.set(value: .init(clock: clock, duration: duration, downstream: downstream))
                }
                guard let throttler = throttleBox.value else { fatalError("Failed to create debouncer") }
                try await Self.check(throttler.downstreamState, throttler.sender)
                switch r {
                    case let .completion(completion):
                        return try await throttler.complete(with: completion)
                    case let .value(value):
                        return try throttler.send(clock.now, value)
                }
            }
        }
    }
}
