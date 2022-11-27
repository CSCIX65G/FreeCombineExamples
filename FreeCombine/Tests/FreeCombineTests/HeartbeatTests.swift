//
//  HeartbeatTests.swift
//  
//
//  Created by Van Simmons on 11/26/22.
//

import XCTest
@testable import FreeCombine

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
final class HeartbeatTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testHeartbeatUntil() async throws {
        let clock = TestClock()
        let end = clock.now.advanced(by: .seconds(1))
        let counter = Counter()
        let heartbeat = Heartbeat(clock: clock, interval: .milliseconds(100), deadline: end)
        let cancellable = await heartbeat.sink { result in
            guard case .value = result else { return }
            clock.advance(by: .milliseconds(100))
            counter.increment()
        }
        clock.advance(by: .milliseconds(100))
        _ = await cancellable.result
        await clock.runToCompletion()
        XCTAssert(counter.count == 10, "Failed due to count = \(counter.count)")
    }
    
    func testHeartbeatFor() async throws {
        let clock = TestClock()
        let counter = Counter()
        let heartbeat = Heartbeat(clock: clock, interval: .milliseconds(100), for: .seconds(1))
        let cancellable = await heartbeat.sink { result in
            guard case .value = result else { return }
            clock.advance(by: .milliseconds(100))
            counter.increment()
        }
        clock.advance(by: .milliseconds(100))
        _ = await cancellable.result
        await clock.runToCompletion()
        XCTAssert(counter.count == 10, "Failed due to count = \(counter.count)")
    }
}
