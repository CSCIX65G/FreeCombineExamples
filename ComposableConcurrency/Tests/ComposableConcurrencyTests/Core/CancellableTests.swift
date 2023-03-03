//
//  CancellableTests.swift
//  
//
//  Created by Van Simmons on 9/18/22.
//

import XCTest
@testable import Core
@testable import Future

final class CancellableTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testIsCancelledThreadLocal() async throws {
        let c = Cancellable<Void>(deinitBehavior: .cancel) {
            try? await Task.sleep(nanoseconds: Duration.seconds(10).inNanoseconds)
            XCTAssert(Task.isCancelled, "Not successfully cancelled")
        }
        XCTAssertNoThrow(try c.cancel(), "Couldn't cancel")
        let can: Void? = try? await c.value
        XCTAssert(can == nil, "Didn't cancel")
        guard case .failure = await c.result else {
            XCTFail("Should not have succeeded")
            return
        }
    }

    func testCancellable() async throws {
        let expectation1 = AsyncPromise<Void>()
        let expectation2 = AsyncPromise<Void>()
        let expectation3 = AsyncPromise<Void>()

        let expectation1a = AsyncPromise<Bool>()
        let expectation2a = AsyncPromise<Bool>()
        let expectation3a = AsyncPromise<Bool>()

        var c: Cancellable<(Cancellable<Void>, Cancellable<Void>, Cancellable<Void>)>? = .none
        c = Cancellable {
            let t1 = Cancellable() {
                try await expectation1.value
                try expectation1a.succeed(true)
            }
            let t2 = Cancellable() {
                try await expectation2.value
                try expectation2a.succeed(true)
            }
            let t3 = Cancellable() {
                try await expectation3.value
                try expectation3a.succeed(true)
            }
            return (t1, t2, t3)
        }
        let r = await c?.result
        if let r {
            XCTAssertNotNil(r, "Not completed")
        } else {
            XCTFail("should exist")
        }

        c = .none

        try await Task.sleep(nanoseconds: 10_000)

        try expectation1.succeed()
        try expectation2.succeed()
        try expectation3.succeed()

        let r1 = try await expectation1a.value
        let r2 = try await expectation2a.value
        let r3 = try await expectation3a.value

        XCTAssert(r1, "Inner task 1 not cancelled")
        XCTAssert(r2, "Inner task 2 not cancelled")
        XCTAssert(r3, "Inner task 3 not cancelled")
    }
}
