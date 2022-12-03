//
//  ClockTests.swift
//  
//
//  Created by Van Simmons on 12/3/22.
//

import XCTest
@testable import FreeCombine
@testable import Channel
@testable import Clock

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
final class ClockTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testTestClockCancellation() async throws {
        let clock = TestClock()

        let cancellable: Cancellable<TestClock.Instant> = .init {
            try await clock.sleep(for: .seconds(5))
            return clock.now
        }

        try await clock.advance(by: .seconds(1))
        try? cancellable.cancel()
        let nowResult = await cancellable.result
        switch nowResult {
            case .success:
                XCTFail("Should not have advanced after cancellation")
            case let .failure(error):
                guard let _ = error as? CancellationError else {
                    XCTFail("Received \(error) instead of CancellationError")
                    return
                }
                XCTAssert(clock.now.offset == .seconds(1))
        }
        await clock.runToCompletion()
    }
}
