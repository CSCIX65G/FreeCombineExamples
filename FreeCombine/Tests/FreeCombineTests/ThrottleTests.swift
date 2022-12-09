//
//  ThrottleTests.swift
//  
//
//  Created by Van Simmons on 12/4/22.
//

import XCTest
import Clock
@testable import FreeCombine

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
final class ThrottleTests: XCTestCase {
    override func setUpWithError() throws { }
    override func tearDownWithError() throws { }

    func testSimpleThrottle() async throws {
        let clock = TestClock()
        let inputCounter = Counter()
        let counter = Counter()
        let t = await (1 ... 15).asyncPublisher
            .handleEvents(receiveOutput: { _ in inputCounter.increment() })
            .throttle(clock: clock, interval: .milliseconds(100), latest: false)
            .sink({ value in
                switch value {
                    case .value(_):
                        counter.increment()
                        return
                    case let .completion(.failure(error)):
                        XCTFail("Got unexpected failure: \(error)")
                        return
                    case .completion(.finished):
                        return
                }
            })
        for _ in 0 ..< 20 {
            try await clock.advance(by: .milliseconds(10))
        }

        _ = await t.result
        await clock.runToCompletion()
        let count = counter.count
        let inputCount = inputCounter.count
        XCTAssert(inputCount == 15, "Got wrong count = \(inputCount)")
        XCTAssert(count >= 1, "Got wrong count = \(count)")
    }

    func testSimpleThrottleLatest() async throws {
        let clock = TestClock()
        let inputCounter = Counter()
        let counter = Counter()

        let subject = try await PassthroughSubject(Int.self)
        let t = await subject.asyncPublisher
            .handleEvents(
                receiveOutput: { value in
                    inputCounter.increment()
                }
            )
            .throttle(clock: clock, interval: .milliseconds(100), latest: true)
            .sink({ value in
                switch value {
                    case .value(_):
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
            try await clock.advance(by: .milliseconds(9))
        }
        try await subject.finish()
        for _ in 0 ..< 20 {
            try await clock.advance(by: .milliseconds(10))
        }
        _ = await t.result

        await clock.runToCompletion()
        let count = counter.count
        let inputCount = inputCounter.count
        XCTAssert(count >= 1, "Got wrong count = \(count)")
        XCTAssert(inputCount == 15, "Got wrong count = \(inputCount)")
    }


    func testSimpleSubjectThrottle() async throws {
        let clock = TestClock()
        let values = MutableBox<[Int]>.init(value: [])
        let inputCounter = Counter()
        let counter = Counter()
        let subject = try await PassthroughSubject(Int.self)
        let t = await subject.asyncPublisher
            .handleEvents(receiveOutput: { _ in inputCounter.increment() })
            .throttle(clock: clock, interval: .milliseconds(100), latest: false)
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
            try await clock.advance(by: .milliseconds(9))
        }
        try await subject.finish()
        for _ in 0 ..< 20 {
            try await clock.advance(by: .milliseconds(10))
        }

        _ = await t.result
        _ = await subject.result

        await clock.runToCompletion()

        let count = counter.count
        XCTAssert(count >= 1, "Got wrong count = \(count)")

        let inputCount = inputCounter.count
        XCTAssert(inputCount == 15, "Got wrong count = \(inputCount)")
    }

    func testSimpleSubjectThrottleLatest() async throws {
        let clock = TestClock()
        let values = MutableBox<[Int]>.init(value: [])
        let inputCounter = Counter()
        let counter = Counter()
        let subject = try await PassthroughSubject(Int.self)
        let t = await subject.asyncPublisher
            .handleEvents(receiveOutput: { _ in inputCounter.increment() })
            .throttle(clock: clock, interval: .milliseconds(100), latest: true)
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
            try await clock.advance(by: .milliseconds(10))
        }
        try await subject.finish()

        for _ in (0 ..< 10) {
            try await clock.advance(by: .milliseconds(100))
        }
        await clock.runToCompletion()

        _ = await t.result
        _ = await subject.result

        let count = counter.count
        XCTAssert(count >= 2, "Got wrong count = \(count)")

        let inputCount = inputCounter.count
        XCTAssert(inputCount == 15, "Got wrong count = \(inputCount)")
    }
}
