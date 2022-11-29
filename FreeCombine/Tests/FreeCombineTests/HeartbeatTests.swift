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
        let end = clock.now.advanced(by: .seconds(5))
        let counter = Counter()
        let heartbeat = Heartbeat(clock: clock, interval: .milliseconds(100), deadline: end)

        let ticker: ValueRef<Resumption<Void>?> = .init(value: .none)
        let cancellable = await heartbeat.sink { result in
            guard case .value = result else { return }
            counter.increment()
            guard let t = ticker.value else { XCTFail("No ticker!"); return }
            ticker.set(value: .none)
            t.resume()
        }
        while clock.now < end {
            await clock.advance(by: .milliseconds(100), waiter: { ticker.set(value: $0) })
        }
        _ = await cancellable.result
        await clock.runToCompletion()
        XCTAssert(counter.count == 50, "Failed \(#function) due to count = \(counter.count)")
    }
    
    func testHeartbeatFor() async throws {
        let clock = TestClock()
        let counter = Counter()
        let heartbeat = Heartbeat(clock: clock, interval: .milliseconds(100), for: .seconds(1))
        let cancellable = await heartbeat.sink { result in
            guard case .value = result else { return }
            counter.increment()
            Task { await clock.advance(by: .milliseconds(100)) }
        }
        await clock.advance(by: .milliseconds(100))
        _ = await cancellable.result
        await clock.runToCompletion()
        XCTAssert(counter.count == 10, "Failed \(#function) due to count = \(counter.count)")
    }
}
