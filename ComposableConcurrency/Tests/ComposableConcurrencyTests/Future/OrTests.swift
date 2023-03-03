//
//  OrTests.swift
//
//
//  Created by Van Simmons on 9/3/22.
//

import XCTest
@testable import Future

final class OrTests: XCTestCase {
    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testSimpleOr() async throws {
        let expectation = await AsyncPromise<Void>()
        let promise1 = await AsyncPromise<Int>()
        let future1 = promise1.future
        let promise2 = await AsyncPromise<Int>()
        let future2 = promise2.future

        let orFuture = or(future1, future2)
        let cancellation = await orFuture.sink { result in
            guard case let .success(either) = result else {
                XCTFail("Failed!")
                return
            }
            var value = -1
            switch either {
                case let .left(v): value = v
                case let .right(v): value = v
            }
            XCTAssert(value == 13 || value == 14, "Bad value")
            do { try expectation.succeed() }
            catch { XCTFail("expectation failed") }
        }

        try promise1.succeed(13)
        try promise2.succeed(14)

        _ = await cancellation.result
    }

    func testSimpleOrFailure() async throws {
        enum Error: Swift.Error, Equatable {
            case iFailed
        }

        let expectation = await AsyncPromise<Void>()
        let promise1 = await AsyncPromise<Int>()
        let future1 = promise1.future
        let promise2 = await AsyncPromise<Int>()
        let future2 = promise2.future

        let orFuture = or(future1, future2)
        let cancellation = await orFuture.sink { result in
            guard case .failure = result else {
                XCTFail("Got a success when should have gotten failure!")
                return
            }
            do { try expectation.succeed() }
            catch { XCTFail("expectation failed") }
        }

        try promise2.fail(Error.iFailed)
        try promise1.cancel()

        _ = await cancellation.result
    }

    func testComplexOr() async throws {
        let expectation = await AsyncPromise<Void>()
        let promise1 = await AsyncPromise<Int>()
        let future1 = promise1.future
        let promise2 = await AsyncPromise<Int>()
        let future2 = promise2.future
        let promise3 = await AsyncPromise<Int>()
        let future3 = promise3.future
        let promise4 = await AsyncPromise<Int>()
        let future4 = promise4.future
        let promise5 = await AsyncPromise<Int>()
        let future5 = promise5.future
        let promise6 = await AsyncPromise<Int>()
        let future6 = promise6.future
        let promise7 = await AsyncPromise<Int>()
        let future7 = promise7.future
        let promise8 = await AsyncPromise<Int>()
        let future8 = promise8.future

        let orFuture = or(future1, future2, future3, future4, future5, future6, future7, future8)
        let cancellation = await orFuture.sink { result in
            guard case let .success(oneOf) = result else {
                XCTFail("Failed!")
                return
            }
            var value = -1
            switch oneOf {
                case let .one(v): value = v
                case let .two(v): value = v
                case let .three(v): value = v
                case let .four(v): value = v
                case let .five(v): value = v
                case let .six(v): value = v
                case let .seven(v): value = v
                case let .eight(v): value = v
            }
            XCTAssert((13 ... 20).contains(value), "Bad value: \(value)")
            do { try expectation.succeed() }
            catch { XCTFail("expectation failed") }
        }

        try promise1.succeed(13)
        try promise2.succeed(14)
        try promise3.succeed(15)
        try promise4.succeed(16)
        try promise5.succeed(17)
        try promise6.succeed(18)
        try promise7.succeed(19)
        try promise8.succeed(20)

        _ = await cancellation.result
    }
}
