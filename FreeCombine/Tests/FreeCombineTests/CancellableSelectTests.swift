//
//  CancellableOrTests.swift
//  
//
//  Created by Van Simmons on 9/13/22.
//

import XCTest

@testable import FreeCombine

final class CancellableOrTests: XCTestCase {

    override func setUpWithError() throws {}

    override func tearDownWithError() throws {}

    func testSimpleOr() async throws {
        let lVal = 13
        let rVal = "hello, world!"
        let expectation: Promise<Void> = await .init()
        let promise1: Promise<Int> = await .init()
        let promise2: Promise<String> = await .init()
        let isLeft = Bool.random()

        let ored = or(promise1.cancellable, promise2.cancellable)
        let cancellable: Cancellable<Void> = .init {
            let result = await ored.result
            try? expectation.succeed()
            guard case let .success(either) = result else {
                XCTFail("Failed")
                return
            }

            if isLeft {
                guard case let .left(receivedLVal) = either else {
                    XCTFail("Bad left chirality: \(either)")
                    return
                }
                XCTAssert(receivedLVal == lVal, "Bad left value")
            } else {
                guard case let .right(receivedRVal) = either else {
                    XCTFail("Bad right chirality: \(either)")
                    return
                }
                XCTAssert(receivedRVal == rVal, "Bad right value")
            }
        }

        if isLeft {
            try? promise1.succeed(lVal)
            _ = await cancellable.result
            try? promise2.succeed(rVal)
        } else {
            try? promise2.succeed(rVal)
            _ = await cancellable.result
            try? promise1.succeed(lVal)
        }
        _ = await expectation.result
    }

    func testCancelOr() async throws {
        let lVal = 13
        let rVal = "hello, world!"
        let expectation: Promise<Void> = await .init()
        let promise1: Promise<Int> = await .init()
        let promise2: Promise<String> = await .init()

        let ored = or(promise1.cancellable, promise2.cancellable)
        let cancellable: Cancellable<Void> = .init {
            let result = await ored.result
            try! expectation.succeed()
            guard case let .failure(error) = result else {
                XCTFail("Failed by succeeding")
                return
            }
            guard nil != error as? CancellationError else {
                XCTFail("Wrong error type in error: \(error)")
                return
            }
        }
        try ored.cancel()
        _ = await expectation.result
        _ = await cancellable.result

        try? promise2.succeed(rVal)
        try? promise1.succeed(lVal)
    }

    func testSimpleOrRightFailure() async throws {
        enum Error: Swift.Error, Equatable {
            case rightFailure
        }
        let lVal = 13
        let expectation: Promise<Void> = await .init()
        let promise1: Promise<Int> = await .init()
        let future1 = promise1.future.delay(.seconds(1))
        let promise2: Promise<String> = await .init()
        let future2 = promise2.future

        let cancellable = await or(future1, future2).sink { result in
            try? expectation.succeed()
            guard case let .failure(error) = result else {
                XCTFail("Failed by succeeding")
                return
            }
            let rightError = error as? Error
            XCTAssertNotNil(rightError, "Wrong error type")
            XCTAssert(.some(rightError) == .some(Error.rightFailure), "Incorrect failure")
        }

        try? promise2.fail(Error.rightFailure)
        _ = await expectation.result
        _ = await cancellable.result
        try? promise1.succeed(lVal)
    }

    func testSimpleOrLeftFailure() async throws {
        enum Error: Swift.Error, Equatable {
            case leftFailure
        }
        let rVal = "Hello, world!"
        let expectation: Promise<Void> = await .init()
        let promise1: Promise<Int> = await .init()
        let future1 = promise1.future
        let promise2: Promise<String> = await .init()
        let future2 = promise2.future.delay(.seconds(1))

        let cancellable = await or(future1, future2).sink { result in
            try? expectation.succeed()
            guard case let .failure(error) = result else {
                XCTFail("Failed by succeeding")
                return
            }
            let leftError = error as? Error
            XCTAssertNotNil(leftError, "Wrong error type")
            XCTAssert(.some(leftError) == .some(Error.leftFailure), "Incorrect failure")
        }

        try? promise1.fail(Error.leftFailure)
        _ = await expectation.result
        _ = await cancellable.result
        try? promise2.succeed(rVal)
    }
}
