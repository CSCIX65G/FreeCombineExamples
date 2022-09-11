//
//  FutureSelectTests.swift
//  
//
//  Created by Van Simmons on 9/10/22.
//

import XCTest

@testable import FreeCombine

final class FutureFirstTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testSimpleFirst() async throws {
//        let lVal = 13
//        let rVal = "hello, world!"
//        let expectation: Promise<Void> = await .init()
//        let promise1: Promise<Int> = await .init()
//        let future1 = promise1.future
//        let promise2: Promise<String> = await .init()
//        let future2 = promise2.future
//
//        let leftFirst = Bool.random()
//
//        let first = first(future1, future2)
//        let cancellable = await first.sink ({ result in
//            try? expectation.succeed()
//            if leftFirst {
//                guard case let .success(.left(left)) = result else {
//                    XCTFail("Wrong chirality: right")
//                    return
//                }
//                XCTAssert(left == lVal, "Bad left value")
//            } else {
//                guard case let .success(.right(right)) = result else {
//                    XCTFail("Wrong chirality: left")
//                    return
//                }
//                XCTAssert(right == rVal, "Bad right value")
//            }
//            return
//        })
//
//        if leftFirst { try? promise1.succeed(lVal) }
//        else { try? promise2.succeed(rVal) }
//
//        _ = await expectation.result
//        _ = await cancellable.result
//
//        if leftFirst { try? promise2.succeed(rVal) }
//        else { try? promise1.succeed(lVal) }
    }
}
