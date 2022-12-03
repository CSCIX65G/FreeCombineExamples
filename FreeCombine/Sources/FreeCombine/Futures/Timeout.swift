//
//  Timeout.swift
//
//
//  Created by Van Simmons on 9/23/22.
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
import Dispatch
#if swift(>=5.7)
@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
public func Timeout<C: Clock>(
    clock: C,
    at deadline: C.Instant,
    tolerance: Swift.Duration? = .none
) -> Future<C.Instant> where C.Duration == Swift.Duration {
    .init(
        clock: clock,
        at: deadline,
        tolerance: tolerance
    )
}

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
public func Timeout<C: Clock>(
    clock: C,
    after duration:  Swift.Duration,
    tolerance: Swift.Duration? = .none
) -> Future<C.Instant> where C.Duration == Swift.Duration {
    .init(
        clock: clock,
        at: clock.now.advanced(by: duration),
        tolerance: tolerance
    )
}

extension Future {
    @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
    public init<C: Clock>(
        clock: C,
        at deadline:  C.Instant,
        tolerance: Swift.Duration? = .none
    ) where Output == C.Instant, C.Duration == Swift.Duration {
        self = Future<C.Instant> { resumption, downstream in
            .init {
                resumption.resume()
                do {
                    if clock.now < deadline {
                        try await clock.sleep(until: deadline, tolerance: tolerance)
                        guard !Cancellables.isCancelled else {
                            _ = await downstream(.failure(CancellationError()))
                            return
                        }
                    }
                    _ = await downstream(.success(clock.now))
                } catch {
                    await downstream(.failure(error))
                }
            }
        }
    }
}
#endif
