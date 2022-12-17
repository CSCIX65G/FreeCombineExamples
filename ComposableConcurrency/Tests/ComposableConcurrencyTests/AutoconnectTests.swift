//
//  ShareTests.swift
//
//
//  Created by Van Simmons on 6/8/22.
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

class AutoconnectTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func xtestSimpleAutoconnect() async throws {
        /*
         p1 and p2 below are NOT guaranteed to see the same number of values bc
         the autoconnected publisher begins publishing as soon as the first subscription
         is connected.  The second subscriber will see only those published
         values that occur after it subscribes.  In some cases it will see zero
         */
        let promise1 = await Promise<Void>()
        let promise2 = await Promise<Void>()

        let n = 100
        let autoconnected = try await (0 ..< n)
            .asyncPublisher
            .map { $0 * 2 }
            .autoconnect(buffering: .bufferingOldest(2))

        let counter1 = Counter()
        let value1 = MutableBox<Int>(value: -1)
        let u1 = await autoconnected.sink({ result in
            switch result {
                case let .value(value):
                    counter1.increment()
                    value1.set(value: value)
                    return
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
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
        })

        let counter2 = Counter()
        let value2 = MutableBox<Int>(value: -1)
        let u2 = await autoconnected.sink { result in
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

        _ = try await u1.value
        try? u2.cancel()
        _ = await u2.result
    }

    func xtestSimpleShortAutoconnect() async throws {
        /*
         p1 and p2 below are NOT guaranteed to see the same number of values bc
         the autoconnectd publisher begins publishing as soon as the first subscription
         is connected.  The second subscriber will see only those published
         values that occur after it subscribes.  In some cases it will see zero
         */
        let promise1 = await Promise<Void>()
        let promise2 = await Promise<Void>()

        let n = 1
        let autoconnected = try await (0 ..< n)
            .asyncPublisher
            .map { $0 * 2 }
            .autoconnect(buffering: .bufferingOldest(2))

        let counter1 = Counter()
        let value1 = MutableBox<Int>(value: -1)
        let u1 = await autoconnected.sink({ result in
            switch result {
                case let .value(value):
                    counter1.increment()
                    value1.set(value: value)
                    return
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
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
        })

        let counter2 = Counter()
        let value2 = MutableBox<Int>(value: -1)
        let u2 = await autoconnected.sink({ result in
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
                    do { try promise2.succeed() }
                    catch { XCTFail("u2 Failed to complete with error: \(error)") }
                    return
            }
        })

        _ = await u1.result
        _ = await u2.result
    }

    func xtestSimpleEmptyAutoconnect() async throws {
        /*
         p1 and p2 below are NOT guaranteed to see the same number of values bc
         the autoconnectd publisher begins publishing as soon as the first subscription
         is connected.  The second subscriber will see only those published
         values that occur after it subscribes.  In some cases it will see zero
         */
        let promise1 = await Promise<Void>()
        let promise2 = await Promise<Void>()

        let n = 0
        let autoconnected = try await (0 ..< n)
            .asyncPublisher
            .map { $0 * 2 }
            .autoconnect()

        let counter1 = Counter()
        let value1 = MutableBox<Int>(value: -1)
        let u1 = await autoconnected.sink { result in
            switch result {
                case let .value(value):
                    counter1.increment()
                    value1.set(value: value)
                    return
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
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
        let value2 = MutableBox<Int>(value: -1)
        let u2 = await autoconnected.sink({ result in
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
                    do { try promise2.succeed() }
                    catch { XCTFail("u2 Failed to complete with error: \(error)") }
                    return
            }
        })

        _ = await u1.result
        _ = await u2.result
    }
    func xtestSubjectAutoconnect() async throws {
        /*
         p1 and p2 below should see the same number of values bc
         we set them up before we send to the subject
         */
        let subject = PassthroughSubject(Int.self)

        /*
         Note that we don't need the `.bufferingOldest(2)` here.  Bc
         we are not trying to simultaneously subscribe and send.
         */
        let publisher = try await subject.asyncPublisher
            .map { $0 % 47 }
            .autoconnect()

        let counter1 = Counter()
        let p1 = await publisher.sink { result in
            switch result {
                case .value:
                    counter1.increment()
                    return
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
                    return
                case .completion(.finished):
                    let count = counter1.count
                    XCTAssert(count == 100, "Incorrect count: \(count) in subscription 1")
                    return
            }
        }

        let counter2 = Counter()
        let p2 = await publisher.sink { result in
            switch result {
                case .value:
                    counter2.increment()
                    return
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
                    return
                case .completion(.finished):
                    let count = counter2.count
                    XCTAssert(count == 100, "Incorrect count: \(count) in subscription 2")
                    return
            }
        }

        for i in (0 ..< 100) {
            do { try await subject.send(i) }
            catch { XCTFail("Failed to send on \(i)") }
        }

        try await subject.finish()
        _ = await p1.result
        _ = await p2.result
        _ = await subject.result
    }
}
