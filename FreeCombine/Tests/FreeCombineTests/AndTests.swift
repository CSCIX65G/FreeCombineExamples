//
//  AndTests.swift
//
//
//  Created by Van Simmons on 9/2/22.
//
//  Created by Van Simmons on 6/8/22.
//
//  Copyright 2022, ComputeCycles, LLC
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//
import XCTest
@testable import FreeCombine

final class AndTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testSimpleAnd() async throws {
        let expectation = await Promise<Void>()
        let promise1 = await Promise<Int>()
        let future1 = promise1.future
        let promise2 = await Promise<String>()
        let future2 = promise2.future

        let andFuture = and(future1, future2)
        let cancellation = await andFuture.sink { result in
            guard case let .success((left, right)) = result else {
                XCTFail("Failed!")
                return
            }
            XCTAssert(left == 13, "Bad left value")
            XCTAssert(right == "m", "Bad right value")
            do { try expectation.succeed() }
            catch { XCTFail("expectation failed") }
        }

        try promise1.succeed(13)
        try promise2.succeed("m")

        _ = await cancellation.result
    }

    func testSimpleAndFailure() async throws {
        enum Error: Swift.Error, Equatable {
            case iFailed
        }

        let expectation = await Promise<Void>()
        let promise1 = await Promise<Int>()
        let future1 = promise1.future
        let promise2 = await Promise<String>()
        let future2 = promise2.future

        let andFuture = and(future1, future2)
        let cancellation = await andFuture.sink { (result: Result<(Int, String), Swift.Error>) in
            guard case .failure = result else {
                XCTFail("Got a success when should have gotten failure!")
                return
            }
            do { try expectation.succeed() }
            catch { XCTFail("expectation failed") }
        }

        try promise1.succeed(13)
        try promise2.fail(Error.iFailed)

        _ = await cancellation.result
    }

    func testComplexAnd() async throws {
        let expectation = await Promise<Void>()
        let promise1 = await Promise<Int>()
        let future1 = promise1.future
        let promise2 = await Promise<String>()
        let future2 = promise2.future
        let promise3 = await Promise<Int>()
        let future3 = promise3.future
        let promise4 = await Promise<String>()
        let future4 = promise4.future
        let promise5 = await Promise<Int>()
        let future5 = promise5.future
        let promise6 = await Promise<String>()
        let future6 = promise6.future
        let promise7 = await Promise<Int>()
        let future7 = promise7.future
        let promise8 = await Promise<String>()
        let future8 = promise8.future

        let andFuture = and(future1, future2, future3, future4, future5, future6, future7, future8)
        let cancellation = await andFuture.sink { result in
            guard case let .success(tuple) = result else {
                XCTFail("Failed!")
                return
            }
            let (one, two, three, four, five, six, seven, eight) = tuple
            XCTAssert(one == 13, "Bad left value")
            XCTAssert(two == "m", "Bad right value")
            XCTAssert(three == 14, "Bad left value")
            XCTAssert(four == "n", "Bad right value")
            XCTAssert(five == 15, "Bad left value")
            XCTAssert(six == "o", "Bad right value")
            XCTAssert(seven == 16, "Bad left value")
            XCTAssert(eight == "p", "Bad right value")
            do { try expectation.succeed() }
            catch { XCTFail("expectation failed") }
        }

        try promise1.succeed(13)
        try promise2.succeed("m")
        try promise3.succeed(14)
        try promise4.succeed("n")
        try promise5.succeed(15)
        try promise6.succeed("o")
        try promise7.succeed(16)
        try promise8.succeed("p")

        _ = await cancellation.result
        do { try await expectation.value }
        catch { XCTFail("Should not have received: \(error)") }
    }
}
