//
//  MakeConnectableTests.swift
//
//
//  Created by Van Simmons on 6/5/22.
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

class MakeConnectableTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testSimpleMakeConnectable() async throws {
        let promise1 = await Promise<Void>()
        let promise2 = await Promise<Void>()

        let connectable = try await UnfoldedSequence(0 ..< 100)
            .makeConnectable()

        let p = connectable.asyncPublisher

        let counter1 = Counter()
        let u1 = await p.sink { (result: Publisher<Int>.Result) in
            switch result {
                case .value:
                    counter1.increment()
                    return
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
                    return
                case .completion(.finished):
                    let count = counter1.count
                    guard count == 100 else {
                        XCTFail("Incorrect count: \(count) in subscription 1")
                        return
                    }
                    do { try promise1.succeed() }
                    catch { XCTFail("Failed to complete with error: \(error)") }
                    return
            }
        }

        let counter2 = Counter()
        let u2 = await p.sink { (result: Publisher<Int>.Result) in
            switch result {
                case .value:
                    counter2.increment()
                    return
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
                    return
                case .completion(.finished):
                    let count = counter2.count
                    guard count == 100 else {
                        XCTFail("Incorrect count: \(count) in subscription 2")
                        return
                    }
                    do { try promise2.succeed() }
                    catch { XCTFail("Failed to complete with error: \(error)") }
                    return
            }
        }

        await connectable.connect()

        _ = try await u1.value
        _ = try await u2.value
        _ = await connectable.result
    }

    func testSubjectMakeConnectable() async throws {
        let subj = PassthroughSubject(Int.self)

        let connectable = try await subj
            .asyncPublisher
            .makeConnectable()

        let counter1 = Counter()
        let u1 = await connectable.asyncPublisher.sink({ result in
            switch result {
                case .value:
                    counter1.increment()
                    return
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
                    return
                case .completion(.finished):
                    let count = counter1.count
                    if count != 100 {
                        XCTFail("Incorrect count: \(count) in subscription 1")
                    }
                    return
            }
        })

        let counter2 = Counter()
        let u2 = await connectable.asyncPublisher.sink { (result: Publisher<Int>.Result) in
            switch result {
                case .value:
                    counter2.increment()
                    return
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
                    return
                case .completion(.finished):
                    let count = counter2.count
                    if count != 100  {
                        XCTFail("Incorrect count: \(count) in subscription 2")
                    }
                    return
            }
        }

        await connectable.connect()

        for i in (0 ..< 100) {
            do { try await subj.send(i) }
            catch { XCTFail("Failed to send on \(i) with error: \(error)") }
        }

        try await subj.finish()
        _ = await subj.result
        _ = await connectable.result
        _ = try await u1.value
        _ = try await u2.value
    }
}
