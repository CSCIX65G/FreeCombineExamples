//
//  FutureSelectTests.swift
//
//
//  Created by Van Simmons on 9/12/22.
//

import XCTest

@testable import FreeCombine

final class FutureSelectTests: XCTestCase {

    override func setUpWithError() throws {}

    override func tearDownWithError() throws {}

    func testSelectStateInit() async throws {
        typealias S = Or<Int, String>
        let left = Succeeded(13)
        let right = Succeeded("hello, world!")
        let channel: Channel<S.Action> = .init(buffering: .bufferingOldest(2))
        let f = S.initialize(left: left, right: right)
        let state = await f(channel)
        _ = await state.leftCancellable?.result
        _ = await state.rightCancellable?.result
        XCTAssertNotNil(state.leftCancellable, "Left was wrong")
        XCTAssertNotNil(state.rightCancellable, "Right was wrong")
    }

    func testSimpleSelect() async throws {
        let lVal = 13
        let rVal = "hello, world!"
        let expectation: Promise<Void> = await .init()
        let promise1: Promise<Int> = await .init()
        let future1 = promise1.future
        let promise2: Promise<String> = await .init()
        let future2 = promise2.future
        let isLeft = Bool.random()

        let cancellable = await or(future1, future2)
            .sink { result in
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

    func testCancelSelect() async throws {
        let lVal = 13
        let rVal = "hello, world!"
        let expectation: Promise<Void> = await .init()
        let promise1: Promise<Int> = await .init()
        let future1 = promise1.future
        let promise2: Promise<String> = await .init()
        let future2 = promise2.future

        let cancellable = await or(future1, future2)
            .sink { result in
                try? expectation.succeed()
                guard case let .failure(error) = result else {
                    XCTFail("Failed by succeeding")
                    return
                }
                let cancelError = error as? Cancellables.Error
                XCTAssertNotNil(cancelError, "Wrong error type")
                XCTAssert(.some(cancelError) == .some(Cancellables.Error.cancelled), "Incorrect failure")
            }
        try cancellable.cancel()
        _ = await expectation.result
        _ = await cancellable.result

        try? promise2.succeed(rVal)
        try? promise1.succeed(lVal)
    }

    func testSimpleSelectRightFailure() async throws {
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

    func testSimpleSelectLeftFailure() async throws {
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

    func testSucceedBeforeTimeout() async throws {
        enum Error: Swift.Error { case iFailed }

        let toDo = await Promise<Int>()
        let timeout = Failed(Never.self, error: Error.iFailed).delay(.milliseconds(10))
        let toDoFuture = toDo.future
        let selectFuture = or(toDoFuture, timeout)
        let cancellable = await selectFuture.sink({ resultEitherIntVoid in
            guard case .success(let eitherIntVoid) = resultEitherIntVoid else {
                XCTFail("should have succeeded. got: \(resultEitherIntVoid)")
                return
            }
            guard case .left(let anInt) = eitherIntVoid else {
                XCTFail("should have gotten left. got: \(eitherIntVoid)")
                return
            }
            guard anInt == 13 else {
                XCTFail("wrong value.  got: \(anInt)")
                return
            }
        })
        try toDo.succeed(13)
        _ = await cancellable.result
    }

    func testFailAfterTimeout() async throws {
        enum Error: Swift.Error { case iFailed }

        let toDo = Succeeded(13).delay(.milliseconds(100))
        let timeout = Failed(Never.self, error: Error.iFailed).delay(.milliseconds(5))
        let selectFuture = or(toDo, timeout)
        let cancellable = await selectFuture.sink({ resultEitherIntVoid in
            guard case .failure(let error) = resultEitherIntVoid else {
                XCTFail("should have failed. got: \(resultEitherIntVoid)")
                return
            }
            guard error is Error else {
                XCTFail("wrong error type.  got: \(error)")
                return
            }
        })
        _ = await cancellable.result
    }
}
