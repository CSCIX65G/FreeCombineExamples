//
//  Heartbeat.swift
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
import Clock
import Core
import Dispatch

#if swift(>=5.7)
@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
public func Heartbeat<C: Clock>(
    function: StaticString = #function,
    file: StaticString = #file,
    line: UInt = #line,
    clock: C,
    interval: Swift.Duration,
    tolerance: Swift.Duration? = .none,
    endingBefore:  C.Instant? = .none,
    tickAtStart: Bool = false
) -> Publisher<C.Instant> where C.Duration == Swift.Duration {
    .init(
        function: function,
        file: file,
        line: line,
        clock: clock,
        interval: interval,
        tolerance: tolerance,
        endingBefore: endingBefore,
        tickAtStart: tickAtStart
    )
}

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
public func Heartbeat<C: Clock>(
    function: StaticString = #function,
    file: StaticString = #file,
    line: UInt = #line,
    clock: C,
    interval: Swift.Duration,
    tolerance: Swift.Duration? = .none,
    for duration:  Swift.Duration,
    tickAtStart: Bool = false
) -> Publisher<C.Instant> where C.Duration == Swift.Duration {
    .init(
        function: function,
        file: file,
        line: line,
        clock: clock,
        interval: interval,
        tolerance: tolerance,
        endingBefore: clock.now.advanced(by: duration),
        tickAtStart: tickAtStart
    )
}

extension Publisher {
    @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
    public init<C: Clock>(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        clock: C,
        interval: Swift.Duration,
        tolerance: Swift.Duration? = .none,
        endingBefore:  C.Instant? = .none,
        tickAtStart: Bool = false
    ) where Output == C.Instant, C.Duration == Swift.Duration {
        self = Publisher<C.Instant> { resumption, downstream in
            .init(function: function, file: file, line: line) {
                let start = clock.now
                var ticks: Int64 = .zero
                let components = interval.components
                try resumption.resume()
                do {
                    if tickAtStart { try await downstream(.value(clock.now)) }
                    while clock.now < (endingBefore ?? clock.now.advanced(by: .seconds(1))) {
                        ticks += 1
                        let fromStart = Swift.Duration.componentMultiply(components, ticks)
                        try await clock.sleep(
                            until: start.advanced(by: fromStart),
                            tolerance: tolerance
                        )
                        guard !Task.isCancelled else {
                            _ = try await downstream(.completion(.finished))
                            throw Publishers.Error.done
                        }
                        _ = try await downstream(.value(clock.now))
                    }
                    _ = try await downstream(.completion(.finished))
                } catch {
                    throw error
                }
            }
        }
    }
}
#endif
