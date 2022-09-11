//
//  PromiseTests.swift
//  UsingFreeCombineTests
//
//  Created by Van Simmons on 9/5/22.
//

import XCTest
import Atomics

@testable import FreeCombine

final class PromiseTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testPromise() async throws {
        let promise: Promise<Int> = await .init()
        let c: Cancellable<Void> = .init(operation: {
            do { try promise.succeed(13) }
            catch { XCTFail("Could not complete") }
        })
        switch await promise.result {
            case .success(let value):
                XCTAssert(value == 13, "Got the wrong value")
            case .failure(let error):
                XCTFail("Got an error: \(error)")
        }
        _ = await c.result
    }
}
