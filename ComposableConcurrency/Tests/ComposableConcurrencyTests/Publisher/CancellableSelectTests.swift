//
//  CancellableOrTests.swift
//  
//
//  Created by Van Simmons on 9/13/22.
//

import XCTest

@testable import Core
@testable import Future
@testable import SendableAtomics

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
final class CancellableOrTests: XCTestCase {

    override func setUpWithError() throws {}

    override func tearDownWithError() throws {}

    func testSimpleOr() async throws {
        let lVal = 13
        let rVal = "hello, world!"
        let expectation: AsyncPromise<Void> = .init()
        let promise1: AsyncPromise<Int> = .init()
        let promise2: AsyncPromise<String> = .init()
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
        let expectation: AsyncPromise<Void> = .init()
        let promise1: AsyncPromise<Int> = .init()
        let promise2: AsyncPromise<String> = .init()

        let ored = or(promise1.cancellable, promise2.cancellable)
        let cancellable: Cancellable<Void> = .init {
            let result = await ored.result
            try! expectation.succeed()
            guard case let .failure(error) = result else {
                XCTFail("Failed by succeeding")
                return
            }
            guard nil != error as? AlreadyWrittenError<Cancellables.Status> else {
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
        let clock = ContinuousClock()
        let expectation: AsyncPromise<Void> = .init()
        let promise1: AsyncPromise<Int> = .init()
        let future1 = promise1.future.delay(clock: clock, duration: .seconds(1))
        let promise2: AsyncPromise<String> = .init()
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
        let expectation: AsyncPromise<Void> = .init()
        let promise1: AsyncPromise<Int> = .init()
        let future1 = promise1.future
        let promise2: AsyncPromise<String> = .init()
        let clock = ContinuousClock()
        let future2 = promise2.future.delay(clock: clock, duration: .seconds(1))

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
