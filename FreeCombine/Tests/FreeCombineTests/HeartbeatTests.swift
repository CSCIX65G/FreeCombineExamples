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

    func testHeartbeat() async throws {
        let clock = TestClock()
        let end = clock.now.advanced(by: .seconds(1))
        let counter = Counter()
        let heartbeat = Heartbeat(clock: clock, interval: .milliseconds(100), until: end)
        let cancellable = await heartbeat.sink { instant in
            counter.increment()
        }
        for _ in 0 ..< 100 { await clock.advance(by: .milliseconds(100)) }
        await clock.run()
        _ = await cancellable.result
        XCTAssert(counter.count == 10, "Failed due to count = \(counter.count)")
    }
}
