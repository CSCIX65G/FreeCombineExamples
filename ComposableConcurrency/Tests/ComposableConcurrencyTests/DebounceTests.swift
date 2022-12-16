//
//  DebounceTests.swift
//  
//
//  Created by Van Simmons on 11/29/22.
//

import XCTest
@testable import Channel
@testable import Clock
@testable import Core
@testable import Queue
@testable import Publisher

struct DebounceTestError: Error { }

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
class DebounceTests: XCTestCase {
    override func setUpWithError() throws {  }
    override func tearDownWithError() throws { }

    func testSingleDebounce() async throws {
        let clock = DiscreteClock()
        let values = MutableBox<[Int]>.init(value: [])
        let inputCounter = Counter()
        let counter = Counter()
        let subject = PassthroughSubject(Int.self)

        let t = await subject.asyncPublisher
            .handleEvents(receiveOutput: { _ in inputCounter.increment() })
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

        for i in (0 ..< 2) {
            try await subject.send(i)
            for _ in 0 ..< 5 { try await clock.advance(by: .milliseconds(10)) }
        }
        try await clock.advance(by: .milliseconds(100))
        try await subject.finish()
        _ = await subject.result
        _ = await t.result

        let inputCount = inputCounter.count
        XCTAssert(inputCount == 2, "Got wrong count = \(inputCount)")

        let count = counter.count
        XCTAssert(count == 1, "Got wrong count = \(count)")

        let vals = values.value
        XCTAssert(vals == [1], "Incorrect values: \(vals)")
    }

    func testSimpleDebounce() async throws {
        let clock = DiscreteClock()
        let values = MutableBox<[Int]>.init(value: [])
        let inputCounter = Counter()
        let counter = Counter()
        let subject = PassthroughSubject(Int.self)
        let t = await subject.asyncPublisher
            .handleEvents(receiveOutput: { _ in inputCounter.increment() })
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
            try await subject.send(i)
            for _ in 0 ..< 5 { try await clock.advance(by: .milliseconds(10)) }
        }
        try await clock.advance(by: .milliseconds(100))
        try await subject.finish()
        _ = await subject.result
        _ = await t.result

        let inputCount = inputCounter.count
        XCTAssert(inputCount == 15, "Got wrong count = \(inputCount)")

        let count = counter.count
        XCTAssert(count >= 1, "Got wrong count = \(count)")

        XCTAssert(values.value.contains(14), "Didn't get the last one")
    }

    func testMoreComplexDebounce() async throws {
        let clock = DiscreteClock()
        let values = MutableBox<[Int]>.init(value: [])
        let inputCounter = Counter()
        let counter = Counter()
        let subject = PassthroughSubject(Int.self, buffering: .unbounded)

        let t = await subject.asyncPublisher
            .handleEvents(receiveOutput: { value in
                inputCounter.increment()
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
            try await subject.send(i)
            let num = i % 2 == 0 ? 5 : 11
            if [1, 3, 5, 7, 9, 11, 13, 14].contains(i) {
                try? await Task.sleep(for: .microseconds(10))
            }
            for _ in 0 ..< num { try await clock.advance(by: .milliseconds(10)) }
        }

        try await clock.advance(by: .milliseconds(100))
        try await subject.finish()
        _ = await subject.result
        _ = await t.result
        await clock.runToCompletion()

        let inputCount = inputCounter.count
        XCTAssert(inputCount == 15, "Got wrong count = \(inputCount)")

        let count = counter.count
        XCTAssert(count >= 8, "Got wrong count = \(count)")
    }

    func testRapidfireDebounce() async throws {
        let clock = DiscreteClock()
        let values = MutableBox<[Int]>.init(value: [])
        let inputCounter = Counter()
        let counter = Counter()
        let subject = PassthroughSubject(Int.self, buffering: .unbounded)

        let t = await subject.asyncPublisher
            .handleEvents(
                receiveOutput: { value in
                    guard value != Int.max else { return }
                    inputCounter.increment()
                }
            )
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
            for _ in 0 ..< 10 { try await subject.send(Int.max) }
            try await subject.send(i)
            let num = i % 2 == 0 ? 5 : 11
            for _ in 0 ..< num { try await clock.advance(by: .milliseconds(10)) }
        }
        try await clock.advance(by: .milliseconds(100))
        try await subject.finish()
        _ = await subject.result
        try await clock.advance(by: .seconds(1000))
        await clock.runToCompletion()
        _ = await t.result

        let inputCount = inputCounter.count
        XCTAssert(inputCount == 15, "Got wrong count = \(inputCount)")

        XCTAssert(values.value.contains(14), "Didn't get the last one: \(values.value)")
    }

    func testDebounceBreak() async throws {
        let clock = DiscreteClock()
        let values = MutableBox<[Int]>.init(value: [])
        let inputCounter = Counter()
        let counter = Counter()
        let subject = PassthroughSubject(Int.self, buffering: .unbounded)

        let t = await subject.asyncPublisher
            .handleEvents(
                receiveOutput: { value in
                    inputCounter.increment()
                }
            )
            .debounce(clock: clock, duration: .milliseconds(100))
            .sink({ value in
                switch value {
                    case .value(let value):
                        guard counter.count < 5 else {
                            XCTFail("Received value after throw")
                            return
                        }
                        let vals = values.value
                        values.set(value: vals + [value])
                        counter.increment()
                        guard counter.count != 5 else { throw DebounceTestError() }
                        return
                    case let .completion(.failure(error)):
                        XCTFail("Got unexpected failure: \(error)")
                        return
                    case .completion(.finished):
                        XCTFail("Got unexpected finish")
                        return
                }
            })

        for i in (0 ..< 15) {
            for _ in 0 ..< 10 {
                try await subject.send(Int.max)
                let num = i % 2 == 0 ? 5 : 11
                for _ in 0 ..< num { try await clock.advance(by: .milliseconds(10)) }
            }
            try await subject.send(i)
            let num = i % 2 == 0 ? 5 : 11
            for _ in 0 ..< num { try await clock.advance(by: .milliseconds(10)) }
        }
        try await clock.advance(by: .milliseconds(100))
        try await subject.finish()
        _ = await subject.result

        await clock.runToCompletion()
        _ = await t.result

        let count = counter.count
        XCTAssert(count == 5, "Got wrong count = \(count)")

        let inputCount = inputCounter.count
        XCTAssert(inputCount >= 10, "Got wrong count = \(inputCount)")

        let vals = values.value
        XCTAssert(vals.count == 5, "Incorrect values: \(vals)")
    }
}
