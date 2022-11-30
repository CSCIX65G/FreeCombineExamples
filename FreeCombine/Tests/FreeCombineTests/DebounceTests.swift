//
//  DebounceTests.swift
//  
//
//  Created by Van Simmons on 11/29/22.
//

import XCTest
@testable import FreeCombine

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
class DebounceTests: XCTestCase {
    override func setUpWithError() throws {  }
    override func tearDownWithError() throws { }

    func xtestSimpleDebounce() async throws {
        let values = ValueRef<[Int]>.init(value: [])
        let inputCounter = Counter()
        let counter = Counter()
        let subject = try await PassthroughSubject(Int.self)
        let t = await subject.asyncPublisher
            .handleEvents(receiveOutput: { _ in inputCounter.increment() })
            .debounce(
                clock: TestClock(),
                duration: .milliseconds(100)
            )
            .sink({ value in
                switch value {
                    case .value(let value):
                        let vals = values.value
                        values.set(value: vals + [value])
                        counter.increment()
                        return
                    case let .completion(.failure(error)):
                        XCTFail("Got unexpected failure: \(error)")
                        return
                    case .completion(.finished):
                        return
                }
            })

        for i in (0 ..< 15) {
            try await subject.send(i)
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        try await Task.sleep(nanoseconds: 100_000_000)

        try await subject.finish()
        _ = await subject.result

        let count = counter.count
        XCTAssert(count == 1, "Got wrong count = \(count)")

        let inputCount = inputCounter.count
        XCTAssert(inputCount == 15, "Got wrong count = \(inputCount)")

        let vals = values.value
        XCTAssert(vals == [14], "Incorrect values: \(vals)")

        _ = await t.result
    }

    func xtestMoreComplexDebounce() async throws {
        let clock = TestClock()
        let values = ValueRef<[Int]>.init(value: [])
        let inputCounter = Counter()
        let counter = Counter()
        let subject = try await PassthroughSubject(Int.self)
        let t = await subject.asyncPublisher
            .handleEvents(receiveOutput: { _ in
                inputCounter.increment()
                print("Count = \(counter.count)")
            })
            .debounce(clock: clock, duration: .milliseconds(100))
            .sink({ value in
                switch value {
                    case .value(let value):
                        let vals = values.value
                        values.set(value: vals + [value])
                        counter.increment()
                        return
                    case let .completion(.failure(error)):
                        XCTFail("Got unexpected failure: \(error)")
                        return
                    case .completion(.finished):
                        return
                }
            })

        for i in (0 ..< 15) {
            try subject.yield(i)
            try await clock.advance(by: i % 2 == 0 ? .milliseconds(50) : .milliseconds(110))
        }
        await clock.runToCompletion()
        try await subject.finish()
        _ = await subject.result

        let count = counter.count
        XCTAssert(count == 8, "Got wrong count = \(count)")

        let inputCount = inputCounter.count
        XCTAssert(inputCount == 15, "Got wrong count = \(inputCount)")

        let vals = values.value
        XCTAssert(vals == [1, 3, 5, 7, 9, 11, 13, 14], "Incorrect values: \(vals)")

        _ = await t.result
    }
}
