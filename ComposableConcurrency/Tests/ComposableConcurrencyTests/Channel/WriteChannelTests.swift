//
//  ProducerTests.swift
//  
//
//  Created by Van Simmons on 12/8/22.
//

@testable import Channel
@testable import Clock
@testable import Core
@testable import Future
import XCTest

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
final class ProducerTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testSimpleProducer() async throws {
        let channel: WriteChannel<Int> = .init()
        let clock = DiscreteClock()
        let readPromise = await Promise<Void>()
        let writePromise = await Promise<Void>()

        let reader = Cancellable<Void> {
            _ = await readPromise.result
            var currentVal = 0
            while true {
                do {
                    if let val = try channel.read() {
                        currentVal += 1
                        XCTAssert(val == currentVal, "Incorrect value received: \(val) instead of \(currentVal)")
                    }
                    _ = try await clock.advance(by: .milliseconds(10))
                    await Task.yield()
                } catch {
                    return
                }
            }
        }

        let writer = Cancellable<Void> {
            _ = await writePromise.result
            for i in 1 ... 10 {
                do {
                    try await channel.write(i)
                    try? await clock.sleep(for: .milliseconds(100))
                }
                catch {
                    XCTFail("Failed to write \(i)")
                    return
                }
            }
            try channel.cancel()
        }

        try writePromise.succeed()
        try readPromise.succeed()

        _ = await reader.result
        _ = await writer.result
    }

    func xtestMVarCancel() async throws {
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
