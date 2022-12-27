//
//  FutureMapTests.swift
//  
//
//  Created by Van Simmons on 12/27/22.
//

import XCTest
@testable import Core
@testable import Future

final class FutureMapTests: XCTestCase {
    override func setUpWithError() throws { }
    override func tearDownWithError() throws {  }

    func testSimpleFutureMap() async throws {
        let expectation = await Promise<Void>()

        let promise = await Promise<Int>()

        let cancellation = await promise.future
            .map { $0 * 2 }
            .sink { result in
                do {
                    try expectation.succeed()
                    _ = await expectation.result
                }
                catch { XCTFail("Already used expectation") }

                switch result {
                    case let .success(value):
                        XCTAssert(value == 26, "wrong value sent: \(value)")
                    case let .failure(error):
                        XCTFail("Got an error? \(error)")
                }
            }

        try promise.succeed(13)
        _ = await cancellation.result
    }
}
