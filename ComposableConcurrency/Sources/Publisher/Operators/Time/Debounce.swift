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
    func debounce<C: Clock>(
        clock: C,
        duration: Swift.Duration
    ) -> Self where C.Duration == Swift.Duration {
        .init { resumption, downstream in
            let downstreamState = ManagedAtomic<Box<DownstreamState>>.init(.init(value: .init()))
            let downstreamValue = ManagedAtomic<Box<(instant: C.Instant, value: Output)>?>.init(.none)
            let queue = Queue<Void>(buffering: .bufferingNewest(1))
            let sender: MutableBox<Cancellable<Void>?> = .init(value: .none)

            return self(onStartup: resumption) { r in
                try await Self.check(downstreamState, sender.value)
                if sender.value == nil {
                    let _: Void = try await pause { resumption in
                        sender.set(
                            value: .init {
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
                        )
                    }
                }

                switch r {
                    case .completion:
                        _ = try? queue.tryYield()
                        queue.finish()
                        try await sender.value?.value ?? ()
                        return try await downstream(r)
                    case let .value(value):
                        _ = downstreamValue.exchange(.init(value:(clock.now, value)), ordering: .sequentiallyConsistent)
                        guard case .terminated = queue.yield() else { return }
                        throw FinishedError()
                }
            }
        }
    }
}
