//
//  CancellationTests.swift
//
//
//  Created by Van Simmons on 5/15/22.
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
@testable import Core
@testable import Future
@testable import Publisher
@testable import SendableAtomics

class CancellationTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testSimpleZipCancellation() async throws {
        let expectation = AsyncPromise<Void>()
        let waiter = AsyncPromise<Void>()
        let startup = AsyncPromise<Void>()

        let publisher1 = (0 ... 100).asyncPublisher
        let publisher2 = "abcdefghijklmnopqrstuvwxyz".asyncPublisher

        let counter = Counter()
        let z1 = await zip(publisher1, publisher2)
            .map { ($0.0 + 100, $0.1.uppercased()) }
            .sink { (result: Publisher<(Int, String)>.Result) in
                switch result {
                    case .value:
                        let count = counter.increment()
                        if count > 9 {
                            try startup.succeed()
                            try await waiter.value
                            return
                        }
                        if Task.isCancelled {
                            XCTFail("Got values after cancellation")
                            do { try expectation.succeed() }
                            catch { XCTFail("Failed to complete: \(error)") }
                            return
                        }
                    case let .completion(.failure(error)):
                        guard let _ = error as? CancellationError else {
                            XCTFail("Got an error? \(error)")
                            return
                        }
                        do { try expectation.succeed() }
                        catch { XCTFail("Failed to complete: \(error)") }
                        return
                    case .completion(.finished):
                        XCTFail("Got to end of task that should have been cancelled")
                        do { try expectation.succeed() }
                        catch { XCTFail("Failed to complete: \(error)") }
                        return
                }
                return
            }

        try await startup.value
        try z1.cancel()
        try waiter.succeed()

        _ = await z1.result
    }

    func testMultiZipCancellation() async throws {
        let expectation = AsyncPromise<Void>()
        let expectation2 = AsyncPromise<Void>()
        let waiter = AsyncPromise<Void>()
        let startup1 = AsyncPromise<Void>()
        let startup2 = AsyncPromise<Void>()

        let publisher1 = UnfoldedSequence(0 ... 100)
        let publisher2 = UnfoldedSequence("abcdefghijklmnopqrstuvwxyz")

        let counter1 = Counter()
        let counter2 = Counter()
        let zipped = zip(publisher1, publisher2)
            .map { ($0.0 + 100, $0.1.uppercased()) }

        let z1 = await zipped.sink({ result in
            switch result {
                case .value:
                    let count2 = counter2.increment()
                    if (count2 == 1) {
                        try startup1.succeed()
                    }
                    return
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
                    return
                case .completion(.finished):
                    let count2 = counter2.count
                    XCTAssertTrue(count2 == 26, "Incorrect count: \(count2)")
                    do { try expectation2.succeed() }
                    catch { XCTFail("Multiple finishes sent: \(error)") }
                    return
            }
        })

        let z2 = await zipped
            .sink({ result in
                switch result {
                    case .value:
                        let count1 = counter1.increment()
                        if count1 == 10 {
                            try startup2.succeed()
                            try await waiter.value
                            return
                        }
                        if count1 > 10 {
                            XCTFail("Received values after cancellation")
                        }
                        return
                    case let .completion(.failure(error)):
                        guard let _ = error as? CancellationError else {
                            XCTFail("Got an error? \(error)")
                            return
                        }
                        do { try expectation.succeed() }
                        catch { XCTFail("Failed to complete: \(error)") }
                        return
                    case .completion(.finished):
                        XCTFail("Got to end of task that should have been cancelled")
                        do { try expectation.succeed() }
                        catch { XCTFail("Multiple finishes sent: \(error)") }
                        return
                }
            })

        try await startup1.value
        try await startup2.value
        try z2.cancel()
        try waiter.succeed()

        _ = await z1.result
        _ = await z2.result
    }

    func testSimpleMergeCancellation() async throws {
        let expectation = AsyncPromise<Void>()
        let waiter = AsyncPromise<Void>()
        let startup = AsyncPromise<Void>()

        let publisher1 = "zyxwvutsrqponmlkjihgfedcba".asyncPublisher
        let publisher2 = "abcdefghijklmnopqrstuvwxyz".asyncPublisher

        let counter = Counter()
        let z1 = await merge(publishers: publisher1, publisher2)
            .map { $0.uppercased() }
            .sink({ result in
                switch result {
                    case .value:
                        let count = counter.increment()
                        if count > 9 {
                            try startup.succeed()
                            try await waiter.value
                        }
                        if count > 10 && Task.isCancelled {
                            XCTFail("Got values after cancellation")
                        }
                        return
                    case let .completion(.failure(error)):
                        guard let _ = error as? CancellationError else {
                            XCTFail("Got an error? \(error)")
                            return
                        }
                        do { try expectation.succeed() }
                        catch { XCTFail("Failed to complete: \(error)") }
                        return
                    case .completion(.finished):
                        XCTFail("Got to end of task that should have been cancelled")
                        do {
                            try expectation.succeed()
                        }
                        catch { XCTFail("Failed to complete: \(error)") }
                        return
                }
            })

        try await startup.value
        try z1.cancel()
        try waiter.succeed()
        _ = await z1.result
    }
}
