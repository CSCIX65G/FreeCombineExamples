//
//  SPSCChannelTests.swift
//
//
//  Created by Van Simmons on 11/28/22.
//

import XCTest
@testable import Core
@testable import Channel
@testable import Future

final class SPSCChannelTests: XCTestCase {
    override func setUpWithError() throws { }
    override func tearDownWithError() throws { }

    func testSPSCChannel() async throws {
        let channel: SPSCSVChannel<Int> = .init(.none)
        let size = 1_000

        let reader = Cancellable<Void> {
            for i in 0 ..< size {
                do {
                    let val = try await channel.read()
                    XCTAssert(val == i, "Invalid value read: \(val), should be: \(i)")
                } catch {
                    XCTFail("Failed to read \(i)")
                }
            }
        }

        let writer = Cancellable<Void> {
            for i in 0 ..< size {
                do { try await channel.write(i) }
                catch { XCTFail("Failed to write \(i)") }
            }
        }
        _ = await reader.result
        _ = await writer.result
    }

    func testSPSCChannelNonBlockingRead() async throws {
        let channel: SPSCSVChannel<Int> = .init(.none)
        let promise = AsyncPromise<Void>()

        let reader = Cancellable<Void> {
            for _ in 0 ..< 100 {
                do { _ = try await channel.read(blocking: false) }
                catch {  }
                try promise.succeed()
                do {
                    let value = try await channel.read()
                    XCTAssert(value == 0, "Incorrect value")
                } catch {
                    XCTFail("Read failure")
                }
            }
        }

        let writer = Cancellable<Void> {
            do {
                _ = await promise.result
                try await channel.write(0)
            }
            catch { XCTFail("Failed to write \(0)") }
        }
        _ = await reader.result
        _ = await writer.result
        _ = await promise.result
    }

    func testSPSCChannelNonBlockingWrite() async throws {
        let channel: SPSCSVChannel<Int> = .init(.none)
        let promise = AsyncPromise<Void>()

        let writer = Cancellable<Void> {
            for i in 0 ..< 100 {
                do { _ = try await channel.write(blocking: false, i) }
                catch { XCTAssert(i != 0, "Failed to write with error: \(error)") }
            }
            try promise.succeed()
        }

        let reader = Cancellable<Void> {
            do {
                _ = await promise.result
                let i = try await channel.read()
                XCTAssert(i == 0, "hmm, wrong value: \(i)")
            }
            catch { XCTFail("Failed to read with error: \(error)") }
        }
        _ = await reader.result
        _ = await writer.result
        _ = await promise.result
    }

    func testSPSCChannelCancel() async throws {
        struct TestError: Error { }

        let mvar: SPSCSVChannel<Int> = .init(.none)

        let reader = Cancellable<Void> {
            for i in 0 ..< 100 {
                do {
                    if i == 47 { try mvar.cancel(with: TestError()) }
                    let val = try await mvar.read()
                    XCTAssert(val == i, "Invalid value read: \(val), should be: \(i)")
                    XCTAssert(val < 47, "Should not read values > 47.  Value - \(i)")
                } catch {
                    if !(error is TestError) {
                        XCTFail("Failed to read \(i)")
                    }
                }
            }
        }

        let writer = Cancellable<Void> {
            for i in 0 ..< 100 {
                do {
                    try await mvar.write(i)
                    if i > 47 { XCTFail("Should not get values > 47.  value = \(i)") }
                }
                catch {
                    if !(error is TestError) || i < 47 {
                        XCTFail("Failed to write \(i)")
                    }
                }
            }
        }
        _ = await reader.result
        _ = await writer.result
    }
}
