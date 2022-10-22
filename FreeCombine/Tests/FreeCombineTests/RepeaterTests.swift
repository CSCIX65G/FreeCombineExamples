//
//  RepeaterTests.swift
//  
//
//  Created by Van Simmons on 10/17/22.
//

import XCTest
@testable import FreeCombine

final class RepeaterTests: XCTestCase {
    typealias ID = Int
    typealias Arg = Int
    typealias Return = String

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testSimpleRepeater() async throws {
        let returnChannel = Channel<IdentifiedRepeater<ID, Arg, Return>.Next>.init(buffering: .bufferingOldest(1))

        let first = await IdentifiedRepeater.repeater(
            id: 0,
            dispatch: { String.init($0) },
            returnChannel: returnChannel
        )
        let cancellable = Cancellable<Void> {
            let max = 10_000
            var i = 0
            first.resumption.resume(returning: i)
            for await next in returnChannel.stream {
                guard case let .success(returnValue) = next.result, returnValue == String(i) else {
                    XCTFail("incorrect value: \(next.result)")
                    return
                }
                i += 1
                if i == max {
                    next.resumption.resume(throwing: CancellationError())
                    returnChannel.finish()
                } else {
                    next.resumption.resume(returning: i)
                }
            }
            return
        }
        _ = await cancellable.result
        _ = await first.repeater.cancellable.result
    }

    func testMultipleRepeaters() async throws {
        let numRepeaters = 100, numValues = 100
        let returnChannel = Channel<IdentifiedRepeater<ID, Arg, Return>.Next>.init(buffering: .bufferingOldest(numRepeaters))
        let cancellable: Cancellable<Void> = .init {
            var iterator = returnChannel.stream.makeAsyncIterator()
            var repeaters: [ID: (repeater: IdentifiedRepeater<ID, Arg, Return>, resumption: Resumption<Arg>)] = [:]
            for i in 0 ..< numRepeaters {
                let first = await IdentifiedRepeater.repeater(
                    id: i,
                    dispatch: { String.init($0) },
                    returnChannel: returnChannel
                )
                repeaters[i] = (repeater: first.repeater, resumption: first.resumption)
            }
            for i in 0 ..< numValues {
                (0 ..< numRepeaters).forEach { n in
                    guard let resumption = repeaters[n]?.resumption else {
                        XCTFail("Could not send")
                        return
                    }
                    resumption.resume(returning: i)
                }
                for _ in 0 ..< numRepeaters {
                    guard let next = await iterator.next() else {
                        XCTFail("Ran out of values")
                        return
                    }
                    guard case let .success(value) = next.result else {
                        XCTFail("Encountered failure")
                        return
                    }
                    guard value == String(i) else {
                        XCTFail("Incorrect value")
                        return
                    }
                    guard let repeater = repeaters[next.id]?.repeater else {
                        XCTFail("Lost repeater")
                        return
                    }
                    repeaters[next.id] = (repeater, next.resumption)
                }
            }
            for n in 0 ..< numRepeaters {
                guard let resumption = repeaters[n]?.resumption else {
                    XCTFail("Could not close")
                    return
                }
                resumption.resume(throwing: CancellationError())

                guard let repeater = repeaters[n]?.repeater else {
                    XCTFail("Could not finishe")
                    return
                }
                _ = await repeater.cancellable.result
            }
        }
        _ = await cancellable.result
    }
}
