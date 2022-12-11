//
//  TimeoutTests.swift
//  
//
//  Created by Van Simmons on 11/30/22.
//

import XCTest
@testable import Channel
@testable import Clock
@testable import Future

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
final class TimeoutTests: XCTestCase {

    override func setUpWithError() throws {  }

    override func tearDownWithError() throws { }

    func testSimpleTimeout() async throws {
        let clock = TestClock()
        let timeout = Timeout(clock: clock, after: .seconds(10))

        let cancellable = await timeout.sink { result in
            guard case .success = result else {
                XCTFail("Timeout failed")
                return
            }
        }

        try await clock.advance(by: .seconds(12))

        _ = await cancellable.result
        await clock.runToCompletion()
    }

    func testOredTimeout() async throws {
        let clock = TestClock()
        let promise = await Promise<Void>()
        let timeout = Timeout(clock: clock, after: .seconds(10))
        let ticker: Channel<Void> = .init()

        let ored = promise.future || timeout

        let cancellable = await ored.sink { result in
            guard case .success(.right) = result else {
                XCTFail("Timeout failed")
                return
            }
            do { try await ticker.write() }
            catch { XCTFail("Failed writing ticker") }
        }

        try await clock.advance(by: .seconds(10))
        try? await ticker.read()
        try await clock.advance(by: .milliseconds(1))
        try promise.succeed()

        _ = await cancellable.result
        await clock.runToCompletion()
    }

    func testOredTimeout2() async throws {
        let clock = TestClock()
        let ticker: Channel<Void> = .init()

        let ored = Timeout(clock: clock, after: .seconds(10))
            || Timeout(clock: clock, after: .milliseconds(10001))

        let cancellable = await ored.sink { result in
            guard case .success(.left) = result else {
                XCTFail("Timeout failed")
                return
            }
            do { try await ticker.write() }
            catch { XCTFail("Failed writing ticker") }
        }

        try await clock.advance(by: .seconds(10))
        try? await ticker.read()
        try await clock.advance(by: .milliseconds(1))

        _ = await cancellable.result
        await clock.runToCompletion()
    }
}
