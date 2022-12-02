//
//  MVarTests.swift
//  
//
//  Created by Van Simmons on 11/28/22.
//

import XCTest
import Channel
@testable import FreeCombine

final class ChannelTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testSimpleChannel() async throws {
        let mvar: Channel<Int> = .init(.none)

        let reader = Cancellable<Void> {
            for i in 0 ..< 100 {
                do {
                    let val = try await mvar.read()
                    XCTAssert(val == i, "Invalid value read: \(val), should be: \(i)")
                } catch {
                    XCTFail("Failed to read \(i)")
                }
            }
        }

        let writer = Cancellable<Void> {
            for i in 0 ..< 100 {
                do { try await mvar.write(i) }
                catch { XCTFail("Failed to write \(i)") }
            }
        }
        _ = await reader.result
        _ = await writer.result
    }

    func testMVarCancel() async throws {
        struct TestError: Error { }

        let mvar: Channel<Int> = .init(.none)

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
