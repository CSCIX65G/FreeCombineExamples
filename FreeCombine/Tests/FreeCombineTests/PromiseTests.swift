//
//  PromiseTests.swift
//  UsingFreeCombineTests
//
//  Created by Van Simmons on 9/5/22.
//

import XCTest
@testable import FreeCombine

final class PromiseTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testPromiseSuccess() async throws {
        let promise: Promise<Int> = await .init()
        let c: Cancellable<Void> = .init(operation: {
            do { try promise.succeed(13) }
            catch { XCTFail("Could not complete") }
        })
        switch await promise.result {
            case .success(let value):
                XCTAssert(value == 13, "Got the wrong value")
            case .failure(let error):
                XCTFail("Got an error: \(error)")
        }
        _ = await c.result
    }

    func testPromiseFailure() async throws {
        enum Error: Swift.Error, Equatable {
            case iFailed
        }
        let promise: Promise<Int> = await .init()
        let c: Cancellable<Void> = .init(operation: {
            do { try promise.fail(Error.iFailed) }
            catch { XCTFail("Could not complete") }
        })
        switch await promise.result {
            case .success(let value):
                XCTFail("Failed by succeeding with value: \(value)")
            case .failure(let error):
                guard let _ = error as? Error else {
                    XCTFail("Wrong error type")
                    return
                }
        }
        _ = await c.result
    }
}
