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
import Dispatch

public func Heartbeat(interval: Duration) -> Publisher<UInt64> {
    .init(interval: interval)
}

extension Publisher where Output == UInt64 {
    public init(interval: Duration, maxTicks: Int = Int.max, tickAtStart: Bool = false) {
        self = .init { resumption, downstream in
            .init {
                resumption.resume()
                let maxTicks = tickAtStart ? maxTicks - 1 : maxTicks
                let start = DispatchTime.now().uptimeNanoseconds
                var ticks: UInt64 = 0
                var current = start
                do {
                    if tickAtStart {
                        _ = try await downstream(.value(current))
                    }
                    while ticks < maxTicks {
                        guard !Cancellables.isCancelled else {
                            return try await handleCancellation(of: downstream)
                        }
                        ticks += 1
                        let next = start + (ticks * interval.inNanoseconds)
                        current = DispatchTime.now().uptimeNanoseconds
                        if current > next { continue }
                        try? await Task.sleep(nanoseconds: next - current)
                        current = DispatchTime.now().uptimeNanoseconds
                        _ = try await downstream(.value(current))
                    }
                    _ = try await downstream(.completion(.finished))
                } catch {
                    throw error
                }
                throw Publishers.Error.done
            }
        }
    }
}

#if swift(>=5.7)
@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
public func Heartbeat<C: Clock>(
    clock: C,
    interval: Swift.Duration,
    tolerance: Swift.Duration? = .none,
    deadline:  C.Instant,
    tickAtStart: Bool = false
) -> Publisher<C.Instant> where C.Duration == Swift.Duration {
    .init(clock: clock, interval: interval, tolerance: tolerance, deadline: deadline, tickAtStart: tickAtStart)
}

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
public func Heartbeat<C: Clock>(
    clock: C,
    interval: Swift.Duration,
    tolerance: Swift.Duration? = .none,
    for duration:  Swift.Duration,
    tickAtStart: Bool = false
) -> Publisher<C.Instant> where C.Duration == Swift.Duration {
    .init(
        clock: clock,
        interval: interval,
        tolerance: tolerance,
        deadline: clock.now.advanced(by: duration),
        tickAtStart: tickAtStart
    )
}

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
extension Swift.Duration {
    static let oneQuintillion: Int64 = 1_000_000_000_000_000_000
    static let oneBillion: Int64 = 1_000_000_000
    static let oneMillion: Int64 = 1_000_000
    static func componentMultiply(_ components: (seconds: Int64, attoseconds: Int64), _ ticks: Int64) -> Self {
        let dattoseconds = Double(components.attoseconds) * Double(ticks) / 1_000_000_000_000_000_000.0
        let dseconds = Double(components.seconds) * Double(ticks)
        let newSeconds = Int64(dseconds + floor(dattoseconds))
        let newDAttoseconds = (((dattoseconds - floor(dattoseconds)) * 1_000_000_000.0).rounded() * 1_000_000_000.0)
        let newAttoseconds = Int64(newDAttoseconds)
        return .init(secondsComponent: newSeconds, attosecondsComponent: newAttoseconds)
    }
}

extension Publisher {
    @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
    public init<C: Clock>(
        clock: C,
        interval: Swift.Duration,
        tolerance: Swift.Duration? = .none,
        deadline:  C.Instant,
        tickAtStart: Bool = false
    ) where Output == C.Instant, C.Duration == Swift.Duration {
        self = Publisher<C.Instant> { resumption, downstream in
                .init {
                    let start = clock.now
                    var ticks: Int64 = .zero
                    let components = interval.components
                    resumption.resume()
                    do {
                        if tickAtStart { try await downstream(.value(clock.now)) }
                        while clock.now < deadline {
                            ticks += 1
                            let fromStart = Swift.Duration.componentMultiply(components, ticks)
//                            Swift.print(fromStart)
                            try await clock.sleep(
                                until: start.advanced(by: fromStart),
                                tolerance: tolerance
                            )
                            guard !Cancellables.isCancelled else {
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
