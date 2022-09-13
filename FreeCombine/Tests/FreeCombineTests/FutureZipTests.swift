//
//  ZipTests.swift
//
//
//  Created by Van Simmons on 9/8/22.
//

import XCTest

@testable import FreeCombine

final class FutureZipTests: XCTestCase {
    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testZipStateInit() async throws {
        let left = Succeeded(13)
        let right = Succeeded("hello, world!")
        let channel: Channel<ZipState<Int, String>.Action> = .init(buffering: .bufferingOldest(2))
        let f = zipInitialize(left: left, right: right)
        let state = await f(channel)
        _ = await state.leftCancellable?.result
        _ = await state.rightCancellable?.result
        XCTAssertNotNil(state.leftCancellable, "Left was wrong")
        XCTAssertNotNil(state.rightCancellable, "Right was wrong")
    }

    func testSimpleZip() async throws {
        let lVal = 13
        let rVal = "hello, world!"
        let expectation: Promise<Void> = await .init()
        let promise1: Promise<Int> = await .init()
        let future1 = promise1.future
        let promise2: Promise<String> = await .init()
        let future2 = promise2.future

        let cancellable = await zip(future1, future2).sink { result in
            try? expectation.succeed()
            guard case let .success((left, right)) = result else {
                XCTFail("Failed")
                return
            }
            XCTAssert(left == lVal, "Bad left value")
            XCTAssert(right == rVal, "Bad right value")
        }

        if Bool.random() {
            try? promise1.succeed(lVal)
            try? promise2.succeed(rVal)
        } else {
            try? promise2.succeed(rVal)
            try? promise1.succeed(lVal)
        }
        _ = await expectation.result
        _ = await cancellable.result
    }

    func testCancelZip() async throws {
        let lVal = 13
        let rVal = "hello, world!"
        let expectation: Promise<Void> = await .init()
        let promise1: Promise<Int> = await .init()
        let future1 = promise1.future
        let promise2: Promise<String> = await .init()
        let future2 = promise2.future

        let cancellable = await zip(future1, future2).sink { result in
            try? expectation.succeed()
            guard case let .failure(error) = result else {
                XCTFail("Failed by succeeding")
                return
            }
            let cancelError = error as? Cancellable<(Int, String)>.Error
            XCTAssertNotNil(cancelError, "Wrong error type")
            XCTAssert(.some(cancelError) == .some(Cancellable<(Int, String)>.Error.cancelled), "Incorrect failure")
        }
        cancellable.cancel()
        _ = await expectation.result
        _ = await cancellable.result

        try? promise2.succeed(rVal)
        try? promise1.succeed(lVal)
    }

    func testSimpleZipRightFailure() async throws {
        enum Error: Swift.Error, Equatable {
            case rightFailure
        }
        let lVal = 13
        let expectation: Promise<Void> = await .init()
        let promise1: Promise<Int> = await .init()
        let future1 = promise1.future.delay(1_000_000_000)
        let promise2: Promise<String> = await .init()
        let future2 = promise2.future

        let cancellable = await zip(future1, future2).sink { result in
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

    func testSimpleZipLeftFailure() async throws {
        enum Error: Swift.Error, Equatable {
            case leftFailure
        }
        let rVal = "Hello, world!"
        let expectation: Promise<Void> = await .init()
        let promise1: Promise<Int> = await .init()
        let future1 = promise1.future
        let promise2: Promise<String> = await .init()
        let future2 = promise2.future.delay(1_000_000_000)

        let cancellable = await zip(future1, future2).sink { result in
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
