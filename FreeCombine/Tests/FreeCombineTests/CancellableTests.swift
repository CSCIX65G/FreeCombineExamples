//
//  CancellableTests.swift
//  
//
//  Created by Van Simmons on 9/18/22.
//

import XCTest
@testable import FreeCombine

final class CancellableTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testIsCancelledThreadLocal() async throws {
        let c = Cancellable<Void> {
            try? await Task.sleep(nanoseconds: Duration.seconds(10).inNanoseconds)
            XCTAssert(Cancellables.isCancelled, "Not successfully cancelled")
        }
        XCTAssertNoThrow(try c.cancel(), "Couldn't cancel")
        XCTAssert(c.isCancelled, "Didn't cancel")
        guard case .failure = await c.result else {
            XCTFail("Should not have succeeded")
            return
        }
    }
}
