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

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
extension Publisher {
    public struct Debouncer<C: Clock> {
        let duration: C.Duration
        let downstream: Downstream
        let downstreamState: ManagedAtomic<Box<DownstreamState>>
        let downstreamValue: ManagedAtomic<Box<(instant: C.Instant, value: Output)>?>
        let queue: Queue<Void>
        private(set) var sender: Cancellable<Void>!

        init(
            clock: C,
            duration: C.Duration,
            downstream: @escaping Downstream,
            downstreamState: ManagedAtomic<Box<DownstreamState>> = .init(.init(value: .init())),
            downstreamValue: ManagedAtomic<Box<(instant: C.Instant, value: Output)>?> = .init(.none),
            queue: Queue<Void> = .init(buffering: .bufferingNewest(1))
        ) async {
            self.duration = duration
            self.downstream = downstream
            self.downstreamState = downstreamState
            self.downstreamValue = downstreamValue
            self.queue = queue
            await unfailingPause { resumption in
                self.sender = .init {
                    resumption.resume()
                    for await _ in queue.stream {
                        var toSendOptional: Output? = .none
                        while let (then, r) = downstreamValue.exchange(.none, ordering: .sequentiallyConsistent)?.value {
                            toSendOptional = r
                            guard clock.now < then.advanced(by: duration) else { break }
                            try await clock.sleep(until: then.advanced(by: duration), tolerance: .none)
                        }
                        guard let toSend = toSendOptional else { continue }
                        do { try await downstream(.value(toSend)) }
                        catch {
                            _ = downstreamState.exchange(.init(value: .init(errored: error)), ordering: .sequentiallyConsistent)
                            queue.finish()
                            for await _ in queue.stream { }
                            return
                        }
                    }
                }
            }
        }

        func send(_ now: C.Instant, _ value: Output) throws -> Void {
            _ = downstreamValue.exchange(.init(value: (now, value)), ordering: .sequentiallyConsistent)
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
    ) -> Self where C.Duration == Swift.Duration {
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
