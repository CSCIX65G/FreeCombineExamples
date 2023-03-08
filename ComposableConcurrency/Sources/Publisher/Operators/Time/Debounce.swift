//
//  Debounce.swift
//
//
//  Created by Van Simmons on 7/8/22.
//
//  Copyright 2022, ComputeCycles, LLC
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//
import Atomics
import Core
import Queue
import SendableAtomics

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
extension Publisher {
    public struct Debouncer<C: Clock>: Sendable {
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
                    try resumption.resume()
                    for await _ in queue.stream {
                        var arr: Array<(instant: C.Instant, value: Output)> = .init()
                        while let next = downstreamValue.exchange(.none, ordering: .sequentiallyConsistent)?.value {
                            arr = arr + next
                            for i in 0 ..< arr.count - 1 {
                                if arr[i].instant.duration(to: arr[i + 1].instant) > duration {
                                    try await downstreamSender(arr[i].value)
                                }
                            }
                            guard clock.now < arr.last!.instant.advanced(by: duration) else { break }
                            try await clock.sleep(until: arr.last!.instant.advanced(by: duration), tolerance: .none)
                            arr = [arr.last!]
                        }
                        guard let toSend = arr.last?.value else { continue }
                        try await downstreamSender(toSend)
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
}

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
extension Publisher {
    func debounce<C: Clock>(
        clock: C,
        duration: Swift.Duration
    ) -> Self where C.Duration == Swift.Duration, C: Sendable {
        .init { resumption, downstream in
            let debouncerBox: MutableBox<Debouncer<C>?> = .init(value: .none)
            return self(onStartup: resumption) { r in
                if debouncerBox.value == nil {
                    await debouncerBox.set(value: .init(clock: clock, duration: duration, downstream: downstream))
                }
                guard let debouncer = debouncerBox.value else { fatalError("Failed to create debouncer") }
                try await Self.check(debouncer.downstreamState, debouncer.sender)
                switch r {
                    case let .completion(completion):
                        return try await debouncer.complete(with: completion)
                    case let .value(value):
                        return try debouncer.send(clock.now, value)
                }
            }
        }
    }
}
