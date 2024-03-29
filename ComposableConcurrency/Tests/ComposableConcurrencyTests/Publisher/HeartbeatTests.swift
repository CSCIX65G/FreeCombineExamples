//
//  HeartbeatTests.swift
//  
//
//  Created by Van Simmons on 11/26/22.
//

import XCTest
@testable import Channel
@testable import Clock
@testable import Core
@testable import Future
@testable import Publisher
@testable import SendableAtomics

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
final class HeartbeatTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testHeartbeatUntil() async throws {
        let clock = DiscreteClock()
        let end = clock.now.advanced(by: .seconds(5))
        let counter = Counter()
        let heartbeat = Heartbeat(clock: clock, interval: .milliseconds(100), endingBefore: end)

        let ticker: Channel<Void> = .init()
        let cancellable = await heartbeat.sink { result in
            guard case .value = result else {
                try? ticker.cancel()
                return
            }
            counter.increment()
            try await ticker.write()
        }
        while clock.now < end {
            for _ in 0 ..< 10 {
                try await clock.advance(by: .milliseconds(10))
            }
            try? await ticker.read()
        }
        _ = await cancellable.result
        await clock.runToCompletion()
        XCTAssert(counter.count == 50, "Failed \(#function) due to count = \(counter.count)")
    }
    
    func testHeartbeatFor() async throws {
        let clock = DiscreteClock()
        let counter = Counter()
        let end = Swift.Duration.seconds(5)
        let endInstant = clock.now.advanced(by: .seconds(5))
        let heartbeat = Heartbeat(clock: clock, interval: .milliseconds(100), for: end)
        
        let ticker: Channel<Void> = .init()
        let cancellable = await heartbeat.sink { result in
            guard case .value = result else {
                try? ticker.cancel()
                return
            }
            counter.increment()
            try await ticker.write()
        }
        while clock.now < endInstant {
            try await clock.advance(by: .milliseconds(50))
            try await clock.advance(by: .milliseconds(50))
            try? await ticker.read()
        }
        for _ in 0 ..< 10 { try await clock.advance(by: .milliseconds(50)) }
        _ = await cancellable.result
        await clock.runToCompletion()
        XCTAssert(counter.count == 50, "Failed \(#function) due to count = \(counter.count)")
    }
}
