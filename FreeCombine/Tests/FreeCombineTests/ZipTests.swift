//
//  ZipTests.swift
//
//
//  Created by Van Simmons on 3/21/22.
//
//  Copyright 2022, ComputeCycles, LLC
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//
import XCTest
@testable import FreeCombine

class ZipTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    enum TestError: Error {
        case failed
    }

    func testSimpleJustZip() async throws {
        let promise = await Promise<Void>()

        let publisher1 = Just(100)
        let publisher2 = Just("abcdefghijklmnopqrstuvwxyz")

        let counter = Counter()

        let c1 = await Zipped(publisher1, publisher2)
            .sink { result in
                let count = counter.count
                switch result {
                    case let .value(value):
                        _ = counter.increment()
                        XCTAssertTrue(value.0 == 100, "Incorrect Int value")
                        XCTAssertTrue(value.1 == "abcdefghijklmnopqrstuvwxyz", "Incorrect String value")
                    case let .completion(.failure(error)):
                        XCTFail("Got an error? \(error)")
                        throw Publishers.Error.done
                    case .completion(.finished):
                        XCTAssert(count == 1, "wrong number of values sent: \(count)")
                        do {  try promise.succeed() }
                        catch { XCTFail("Failed to complete promise: \(error)") }
                        throw Publishers.Error.done
                }
                return .more
            }

        do { _ = try await promise.value }
        catch {
            XCTFail("Timed out, count = \(counter.count)")
        }
        _ = await c1.result
    }

    func testEmptyZip() async throws {
        let promise = await Promise<Void>()

        let publisher1 = Just(100)
        let publisher2 = Empty(String.self)

        let counter = Counter()

        let z1 = await zip(publisher1, publisher2)
            .sink { result in
                let count = counter.count
                switch result {
                    case let .value(value):
                        _ = counter.increment()
                        XCTFail("Should not have received a value: \(value)")
                    case let .completion(.failure(error)):
                        XCTFail("Got an error? \(error)")
                    case .completion(.finished):
                        XCTAssert(count == 0, "wrong number of values sent: \(count)")
                        do {  try promise.succeed() }
                        catch { XCTFail("Failed to complete: \(error)") }
                        throw Publishers.Error.done
                }
                return .more
            }

        do { _ = try await promise.value }
        catch {
            let count = counter.count
            XCTFail("Timed out, count = \(count)")
        }
        _ = await z1.result
    }

    func testSimpleSequenceZip() async throws {
        let promise = await Promise<Void>()

        let publisher1 = (0 ... 100).asyncPublisher
        let publisher2 = "abcdefghijklmnopqrstuvwxyz".asyncPublisher

        let counter = Counter()
        let z1 = await zip(publisher1, publisher2)
            .sink { result in
                let count = counter.count
                switch result {
                    case .value:
                        _ = counter.increment()
                        return .more
                    case let .completion(.failure(error)):
                        XCTFail("Got an error? \(error)")
                        throw Publishers.Error.done
                    case .completion(.finished):
                        XCTAssert(count == 26, "wrong number of values sent: \(count)")
                        do {  try promise.succeed() }
                        catch { XCTFail("Failed to complete: \(error)") }
                        throw Publishers.Error.done
                }
            }

        do { _ = try await promise.value }
        catch { XCTFail("Timed out, count = \(counter.count)") }
        _ = await z1.result
    }

    func testSimpleZipCancellation() async throws {
        let expectation = await Promise<Void>()
        let waiter = await Promise<Void>()
        let startup = await Promise<Void>()

        let publisher1 = (0 ... 100).asyncPublisher
        let publisher2 = "abcdefghijklmnopqrstuvwxyz".asyncPublisher

        let counter = Counter()
        let z1 = await zip(publisher1, publisher2)
            .map { ($0.0 + 100, $0.1.uppercased()) }
            .sink { result in
                switch result {
                    case .value:
                        let count = counter.increment()
                        if count == 10 {
                            try startup.succeed()
                            try await waiter.value
                            return .more
                        }
                        if count > 10 {
                            XCTFail("Got values after cancellation")
                            do { try expectation.succeed() }
                            catch { XCTFail("Failed to complete: \(error)") }
                            throw TestError.failed
                        }
                    case let .completion(.failure(error)):
                        guard error is CancellationError else {
                            XCTFail("Did not cancel")
                            try expectation.succeed()
                            throw TestError.failed
                        }
                        do { try expectation.succeed() }
                        catch { XCTFail("Failed to complete: \(error)") }
                        throw Publishers.Error.done
                    case .completion(.finished):
                        XCTFail("Got to end of task that should have been cancelled")
                        do { try expectation.succeed() }
                        catch { XCTFail("Failed to complete: \(error)") }
                        throw Publishers.Error.done
                }
                return .more
            }

        do {
            try await startup.value
            try z1.cancel()
            try waiter.succeed()
        } catch {
            XCTFail("Failed with error: \(error)")
        }

        _ = await z1.result
        do {
            try expectation.succeed()
            XCTFail("Should not have succeeded expectation")
        } catch { }
        do {
            try waiter.succeed()
            XCTFail("Should not have succeeded waiter")
        } catch { }
        do {
            try startup.succeed()
            XCTFail("Should not have succeeded startup")
        } catch { }
    }

    func testMultiZipCancellation() async throws {
        let expectation = await Promise<Void>()
        let expectation2 = await Promise<Void>()
        let waiter = await Promise<Void>()
        let startup1 = await Promise<Void>()
        let startup2 = await Promise<Void>()

        let publisher1 = Unfolded(0 ... 100)
        let publisher2 = Unfolded("abcdefghijklmnopqrstuvwxyz")

        let counter1 = Counter()
        let counter2 = Counter()
        let zipped = zip(publisher1, publisher2)
            .map { ($0.0 + 100, $0.1.uppercased()) }

        let z1 = await zipped.sink { result in
            switch result {
                case .value:
                    let count2 = counter2.increment()
                    if (count2 == 1) {
                        try startup1.succeed()
                    }
                    return .more
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
                    throw Publishers.Error.done
                case .completion(.finished):
                    let count2 = counter2.count
                    XCTAssertTrue(count2 == 26, "Incorrect count: \(count2)")
                    do { try expectation2.succeed() }
                    catch { XCTFail("Multiple finishes sent: \(error)") }
                    throw Publishers.Error.done
            }
        }

        let z2 = await zipped
            .sink { result in
                switch result {
                    case .value:
                        let count1 = counter1.increment()
                        if count1 == 10 {
                            try startup2.succeed()
                            try await waiter.value
                            return .more
                        }
                        if count1 > 10 {
                            XCTFail("Received values after cancellation.  count: \(count1)")
                        }
                        return .more
                    case let .completion(.failure(error)):
                        if error as? CancellationError == nil {
                            XCTFail("Failed with wrong error: \(error)")
                        }
                        try expectation.succeed()
                        throw Publishers.Error.done
                    case .completion(.finished):
                        XCTFail("Got to end of task that should have been cancelled")
                        do { try expectation.succeed() }
                        catch { XCTFail("Multiple finishes sent: \(error)") }
                        throw Publishers.Error.done
                }
            }

        do {
            try await startup1.value
            try await startup2.value
            try z2.cancel()
            try waiter.succeed()
        } catch {
            XCTFail("Failed with error: \(error)")
        }

        _ = await expectation.result
        _ = await expectation2.result
        _ = await z1.result
        _ = await z2.result
    }

    func testSimpleZip() async throws {
        let promise = await Promise<Void>()

        let publisher1 = (0 ... 100).asyncPublisher
        let publisher2 = Unfolded("abcdefghijklmnopqrstuvwxyz")

        let counter = Counter()

        let z1 = await zip(publisher1, publisher2)
            .map {value in (value.0 + 100, value.1.uppercased()) }
            .sink({ result in
                switch result {
                    case .value:
                        counter.increment()
                        return .more
                    case let .completion(.failure(error)):
                        XCTFail("Got an error? \(error)")
                        throw Publishers.Error.done
                    case .completion(.finished):
                        let count = counter.count
                        XCTAssert(count == 26, "wrong number of values sent: \(count)")
                        do { try promise.succeed() }
                        catch { XCTFail("Failed to complete: \(error)") }
                        throw Publishers.Error.done
                }
            })

        do { _ = try await promise.value }
        catch { XCTFail("Timed out, count = \(counter.count)") }
        _ = await z1.result
    }

    func testComplexZip() async throws {
        let promise = await Promise<Void>()

        let p1 = Unfolded(0 ... 100)
        let p2 = Unfolded("abcdefghijklmnopqrstuvwxyz")
        let p3 = Unfolded(0 ... 100)
        let p4 = Unfolded("abcdefghijklmnopqrstuvwxyz")
        let p5 = Unfolded(0 ... 100)
        let p6 = Unfolded("abcdefghijklmnopqrstuvwxyz")
        let p7 = Unfolded(0 ... 100)
        let p8 = Unfolded("abcdefghijklmnopqrstuvwxyz")

        let counter = Counter()
        let z1 = await zip(p1, p2, p3, p4, p5, p6, p7, p8)
            .map { v in
                (v.0 + 100, v.1.uppercased(), v.2 + 110, v.3, v.4 + 120, v.5.uppercased(), v.6 + 130, v.7 )
            }
            .sink { result in
                switch result {
                    case .value:
                        counter.increment()
                        return .more
                    case let .completion(.failure(error)):
                        XCTFail("Got an error? \(error)")
                        throw Publishers.Error.done
                    case .completion(.finished):
                        let count = counter.count
                        XCTAssert(count == 26, "wrong number of values sent: \(count)")
                        do { try promise.succeed() }
                        catch { XCTFail("Multiple finishes sent: \(error)") }
                        throw Publishers.Error.done
                }
            }

        do { _ = try await promise.value }
        catch { XCTFail("Timed out, count = \(counter.count)") }
        let _ = await z1.result
    }

    func testMultiComplexZip() async throws {
        let promise1 = await Promise<Void>()
        let promise2 = await Promise<Void>()

        let p1 = Unfolded(0 ... 100)
        let p2 = Unfolded("abcdefghijklmnopqrstuvwxyz")
        let p3 = Unfolded(0 ... 100)
        let p4 = Unfolded("abcdefghijklmnopqrstuvwxyz")
        let p5 = Unfolded(0 ... 100)
        let p6 = Unfolded("abcdefghijklmnopqrstuvwxyz")
        let p7 = Unfolded(0 ... 100)
        let p8 = Unfolded("abcdefghijklmnopqrstuvwxyz")

        let zipped = zip(p1, p2, p3, p4, p5, p6, p7, p8)

        let count1 = Counter()
        let z1 = await zipped
            .map { v in
                (v.0 + 100, v.1.uppercased(), v.2 + 110, v.3, v.4 + 120, v.5.uppercased(), v.6 + 130, v.7 )
            }
            .sink { result in
                switch result {
                    case .value:
                        count1.increment()
                        return .more
                    case let .completion(.failure(error)):
                        XCTFail("Got an error? \(error)")
                        throw Publishers.Error.done
                    case .completion(.finished):
                        let count = count1.count
                        XCTAssert(count == 26, "wrong number of values sent: \(count1)")
                        try promise1.succeed()
                        throw Publishers.Error.done
                }
            }

        let count2 = Counter()
        let z2 = await zipped
            .map { v in
                (v.0 + 100, v.1.uppercased(), v.2 + 110, v.3, v.4 + 120, v.5.uppercased(), v.6 + 130, v.7 )
            }
            .sink { result in
                switch result {
                    case .value:
                        count2.increment()
                        return .more
                    case let .completion(.failure(error)):
                        XCTFail("Got an error? \(error)")
                        return .more
                    case .completion(.finished):
                        let count = count2.count
                        XCTAssert(count == 26, "wrong number of values sent: \(count)")
                        try promise2.succeed()
                        throw Publishers.Error.done
                }
            }

        do {
            _ = try await promise1.value
            _ = try await promise2.value
        } catch {
            XCTFail("Timed out")
        }
        _ = await z1.result
        _ = await z2.result
    }
}
