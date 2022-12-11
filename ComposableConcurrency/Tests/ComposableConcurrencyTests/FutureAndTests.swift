//
//  FutureAndTests.swift
//
//
//  Created by Van Simmons on 9/8/22.
//

import XCTest

@testable import Queue
@testable import Future

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
final class FutureAndTests: XCTestCase {
    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testAndStateInit() async throws {
        typealias Z2 = And<Int, String>
        let left = Succeeded(13)
        let right = Succeeded("hello, world!")
        let channel: Queue<Z2.Action> = .init(buffering: .bufferingOldest(2))
        let f = Z2.initialize(left: left, right: right)
        let state = await f(channel)
        _ = await state.leftCancellable?.result
        _ = await state.rightCancellable?.result
        XCTAssertNotNil(state.leftCancellable, "Left was wrong")
        XCTAssertNotNil(state.rightCancellable, "Right was wrong")
    }

    func testSimpleAnd() async throws {
        let lVal = 13
        let rVal = "hello, world!"
        let expectation: Promise<Void> = await .init()
        let promise1: Promise<Int> = await .init()
        let future1 = promise1.future
        let promise2: Promise<String> = await .init()
        let future2 = promise2.future

        let cancellable = await and(future1, future2)
            .sink { result in
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

    func testCancelAnd() async throws {
        let lVal = 13
        let rVal = "hello, world!"
        let expectation: Promise<Void> = await .init()
        let promise1: Promise<Int> = await .init()
        let future1 = promise1.future
        let promise2: Promise<String> = await .init()
        let future2 = promise2.future

        let cancellable = await and(future1, future2)
            .sink { result in
                try? expectation.succeed()
                guard case let .failure(error) = result else {
                    XCTFail("Failed by succeeding")
                    return
                }
                let cancelError = error as? CancellationError
                XCTAssertNotNil(cancelError, "Wrong error type")
            }
        try cancellable.cancel()
        _ = await expectation.result
        _ = await cancellable.result

        try? promise2.succeed(rVal)
        try? promise1.succeed(lVal)
    }

    func testSimpleAndRightFailure() async throws {
        enum Error: Swift.Error, Equatable {
            case rightFailure
        }
        let lVal = 13
        let expectation: Promise<Void> = await .init()
        let promise1: Promise<Int> = await .init()
        let clock = ContinuousClock()
        let future1 = promise1.future.delay(clock: clock, duration: .seconds(1))
        let promise2: Promise<String> = await .init()
        let future2 = promise2.future

        let cancellable = await and(future1, future2)
            .sink { result in
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

    func testSimpleAndLeftFailure() async throws {
        enum Error: Swift.Error, Equatable {
            case leftFailure
        }
        let rVal = "Hello, world!"
        let expectation: Promise<Void> = await .init()
        let promise1: Promise<Int> = await .init()
        let future1 = promise1.future
        let promise2: Promise<String> = await .init()
        let clock = ContinuousClock()
        let future2 = promise2.future.delay(clock: clock, duration: .seconds(1))

        let cancellable = await and(future1, future2)
            .sink { result in
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

    func testSimpleAndOperator() async throws {
        let lVal = 13
        let rVal = "hello, world!"
        let expectation: Promise<Void> = await .init()
        let promise1: Promise<Int> = await .init()
        let future1 = promise1.future
        let promise2: Promise<String> = await .init()
        let future2 = promise2.future

        let cancellable = await (future1 && future2)
            .sink { result in
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
}
