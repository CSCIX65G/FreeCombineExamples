//
//  ChannelTests.swift
//  
//
//  Created by Van Simmons on 11/28/22.
//

import XCTest
@testable import Core
@testable import Channel
@testable import Future
@testable import SendableAtomics

final class ChannelTests: XCTestCase {
    override func setUpWithError() throws { }
    override func tearDownWithError() throws { }

    func testChannel() async throws {
        let channel: Channel<Int> = .init()
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
                do { try await channel.write(.value(i)) }
                catch { XCTFail("Failed to write \(i)") }
            }
        }
        _ = await reader.result
        _ = await writer.result
    }

    func testMultiProducerChannel() async throws {
        let numberOfProducers = 100
        let size = 10
        let channel: Channel<Int> = .init(buffering: .oldest(numberOfProducers))

        let reader = Cancellable<Void> {
            var sum = 0
            for i in 0 ..< size * numberOfProducers {
                do {
                    sum += try await channel.read()
                } catch {
                    XCTFail("Failed to read \(i) error: \(error)")
                }
            }
            XCTAssert(sum == 4500, "didn't get the values we expected: \(sum)")
        }


        let writers = (0 ..< numberOfProducers).map { _ in
            Cancellable<Void> {
                for i in 0 ..< size {
                    do { try await channel.write(.value(i)) }
                    catch { XCTFail("Failed to write \(i)") }
                }
            }
        }
        _ = await reader.result

        for i in (0 ..< numberOfProducers) {
            _ = await writers[i].result
        }
    }

    func testMultiProducerMultiReaderChannel() async throws {
        let numberOfProducers = Int.random(in: 50 ..< 150)
        let size = Int.random(in: 0 ..< 20)
        let sum = (0 ..< size).reduce(0, +)
        let channel: Channel<Int> = .init(buffering: .oldest(numberOfProducers))
        let counter = Counter()

        let readers = (0 ..< numberOfProducers).map { _ in
            Cancellable<Void> {
                for i in 0 ..< size {
                    do {
                        counter.increment(by: try await channel.read())
                    } catch {
                        XCTFail("Failed to read \(i) error: \(error)")
                    }
                }
            }
        }

        let writers = (0 ..< numberOfProducers).map { _ in
            Cancellable<Void> {
                for i in 0 ..< size {
                    do { try await channel.write(.value(i)) }
                    catch { XCTFail("Failed to write \(i)") }
                }
            }
        }

        for i in (0 ..< numberOfProducers) {
            _ = await readers[i].result
            _ = await writers[i].result
        }
        XCTAssert(counter.count == numberOfProducers * sum, "didn't get the values we expected: \(counter.count)")
    }

    func testChannelCancel() async throws {
        struct TestError: Error { }

        let channel: Channel<Int> = .init()

        let maxValues = Int.random(in: 50 ..< 200)
        let stopAfter = Int.random(in: 0 ..< maxValues)

        let reader = Cancellable<Void> {
            for i in 0 ..< maxValues {
                do {
                    if i == stopAfter { try channel.cancel(with: TestError()) }
                    let val = try await channel.read()
                    XCTAssert(val == i, "Invalid value read: \(val), should be: \(i)")
                    XCTAssert(val < stopAfter, "Should not read values > stopAfter.  Value - \(i)")
                } catch {
                    if !(error is TestError) {
                        XCTFail("Failed to read \(i) with error: \(error)")
                    }
                }
            }
        }

        let writer = Cancellable<Void> {
            for i in 0 ..< maxValues {
                do {
                    try await channel.write(.value(i))
                    if i > stopAfter {
                        XCTFail("Should not get values > stopAfter.  value = \(i)")
                    }
                }
                catch {
                    if !(error is TestError) || i < stopAfter {
                        XCTFail("Failed to write \(i) with error: \(error)")
                        break
                    }
                }
            }
        }
        _ = await reader.result
        _ = await writer.result
    }
}
