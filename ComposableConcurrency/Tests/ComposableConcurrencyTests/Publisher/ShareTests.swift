//
//  ShareTests.swift
//
//
//  Created by Van Simmons on 6/27/22.
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

final class ShareTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testSimpleShare() async throws {
        /*
         p1 and p2 below are NOT guaranteed to see the same number of values bc
         the share publisher begins publishing as soon as the first subscription
         is connected.  The second subscriber will see only those published
         values that occur after it subscribes.  In some cases it will see zero
         */
        let promise1 = AsyncPromise<Void>()
        let promise2 = AsyncPromise<Void>()

        let n = 100
        let upstreamCounter = Counter()
        let upstreamValue = MutableBox<Int>(value: -1)
        let upstreamShared = MutableBox<Bool>(value: false)
        let shared = await (0 ..< n)
            .asyncPublisher
            .handleEvents(
                receiveDownstream: { _ in
                    Task<Void, Swift.Error> {
                        guard upstreamShared.value == false else {
                            XCTFail("Shared more than once")
                            return
                        }
                        upstreamShared.set(value: true)
                    }
                },
                receiveOutput: { value in
                    upstreamCounter.increment()
                    upstreamValue.set(value: value)
                },
                receiveFinished: {
                    let count = upstreamCounter.count
                    XCTAssert(count == n, "Wrong number sent, expected: \(n), got: \(count)")
                },
                receiveFailure: { error in
                    XCTFail("Inappropriately failed with: \(error)")
                }
            )
            .share()

        let counter1 = Counter()
        let value1 = MutableBox<Int>(value: 0)
        let u1 = await shared.asyncPublisher().sink { result in
            switch result {
                case let .value(value):
                    guard value == counter1.count else {
                        XCTFail("missing message, value = \(value), counter = \(counter1.count)")
                        return
                    }
                    counter1.increment()
                    value1.set(value: value)
                    return
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
                    do { try promise1.succeed() }
                    catch { XCTFail("u1 Failed to complete with error: \(error)") }
                    return
                case .completion(.finished):
                    let count = counter1.count
                    guard count == n else {
                        XCTFail("Incorrect count: \(count) in subscription 1")
                        return
                    }
                    do { try promise1.succeed() }
                    catch { XCTFail("u1 Failed to complete with error: \(error)") }
                    return
            }
        }

        let counter2 = Counter()
        let value2 = MutableBox<Int>(value: 0)
        let u2 = await shared.asyncPublisher().sink { result in
            switch result {
                case let .value(value):
                    counter2.increment()
                    value2.set(value: value)
                    return
                case let .completion(.failure(error)):
                    XCTFail("u2 completed with error: \(error)")
                    do { try promise2.succeed() }
                    catch { XCTFail("u2 Failed to complete with error: \(error)") }
                    return
                case .completion(.finished):
                    // NB: the number of values received here is unpredictable
                    // and may be anything 0 ... n
                    let count = counter2.count
                    XCTAssert(count <= n, "How'd we get so many?")
                    do { try promise2.succeed() }
                    catch { XCTFail("u2 Failed to complete with error: \(error)") }
                    return
            }
        }

        try await shared.connect()

        _ = await u1.result
        _ = await u2.result

        do { _ = try await promise1.value }
        catch {
            let last = value1.value
            XCTFail("u1 Timed out count = \(counter1.count), last = \(last)")
        }

        do { _ = try await promise2.value } catch {
            let last = value2.value
            XCTFail("u2 Timed out count = \(counter2.count), last = \(last)")
        }

    }
}
