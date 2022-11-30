//
//  Duration.swift
//  
//
//  Created by Van Simmons on 9/17/22.
//
public enum Duration {
    case seconds(UInt64)
    case milliseconds(UInt64)
    case microseconds(UInt64)
    case nanoseconds(UInt64)

    public var inNanoseconds: UInt64 {
        switch self {
            case .seconds(let seconds):
                return seconds * 1_000_000_000
            case .milliseconds(let milliseconds):
                return milliseconds * 1_000_000
            case .microseconds(let microseconds):
                return microseconds * 1_000
            case .nanoseconds(let nanoseconds):
                return nanoseconds
        }
    }
}

import Foundation
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
