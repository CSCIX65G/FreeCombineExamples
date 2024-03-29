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
@testable import SendableAtomics

class AutoconnectTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testSimpleAutoconnect() async throws {
        /*
         p1 and p2 below are NOT guaranteed to see the same number of values bc
         the autoconnected publisher begins publishing as soon as the first subscription
         is connected.  The second subscriber will see only those published
         values that occur after it subscribes.  In some cases it will see zero
         */
        let n = 100
        let autoconnected = await (0 ..< n)
            .asyncPublisher()
            .map { $0 * 2 }
            .autoconnect()

        let counter1 = Counter()
        let u1 = await autoconnected.asyncPublisher().sink { result in
            switch result {
                case .value:
                    counter1.increment()
                    return
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
                    return
                case .completion(.finished):
                    let count = counter1.count
                    guard count == n else {
                        XCTAssert(count <= n, "How'd we get: \(count)?")
                        return
                    }
                    return
            }
        }

        let counter2 = Counter()
        let u2 = await autoconnected.asyncPublisher().sink { result in
            switch result {
                case .value:
                    counter2.increment()
                    return
                case .completion:
                    // NB: the number of values received here is unpredictable
                    // and may be anything 0 ... n
                    let count = counter2.count
                    XCTAssert(count <= n, "How'd we get: \(count)?")
                    return
            }
        }

        _ = await u1.result
        _ = await u2.result
        _ = await autoconnected.result
    }

    func testSimpleShortAutoconnect() async throws {
        /*
         p1 and p2 below are NOT guaranteed to see the same number of values bc
         the autoconnectd publisher begins publishing as soon as the first subscription
         is connected.  The second subscriber will see only those published
         values that occur after it subscribes.  In some cases it will see zero
         */
        let n = 1
        let autoconnected = await (0 ..< n)
            .asyncPublisher()
            .map { $0 * 2 }
            .autoconnect()

        let counter1 = Counter()
        let value1 = MutableBox<Int>(value: -1)
        let u1 = await autoconnected.asyncPublisher().sink { result in
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
                    return
            }
        }

        let counter2 = Counter()
        let value2 = MutableBox<Int>(value: -1)
        let u2 = await autoconnected.asyncPublisher().sink { result in
            switch result {
                case let .value(value):
                    counter2.increment()
                    value2.set(value: value)
                    return
                case .completion(.failure):
                    // NB this might happen if the stream has already completed by the time
                    // our subscription goes through
                    return
                case .completion(.finished):
                    // NB: the number of values received here is unpredictable
                    return
            }
        }

        _ = await u1.result
        _ = await u2.result
    }

    func testSimpleEmptyAutoconnect() async throws {
        /*
         p1 and p2 below are NOT guaranteed to see the same number of values bc
         the autoconnectd publisher begins publishing as soon as the first subscription
         is connected.  The second subscriber will see only those published
         values that occur after it subscribes.  In some cases it will see zero
         */

        let n = 0
        let autoconnected = await (0 ..< n).asyncPublisher
            .map { $0 * 2 }
            .autoconnect()

        let counter1 = Counter()
        let value1 = MutableBox<Int>(value: 0)
        let u1 = await autoconnected.asyncPublisher().sink { result in
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
                    return
            }
        }

        let u2 = await autoconnected.asyncPublisher().sink { _ in  }

        _ = await autoconnected.result
        _ = await u1.result
        _ = await u2.result
    }

    func testSubjectAutoconnect() async throws {
        /*
         p1 and p2 below should see the same number of values bc
         we set them up before we send to the subject
         */
        let subject = PassthroughSubject(Int.self)

        /*
         Note that we don't need the `.bufferingOldest(2)` here.  Bc
         we are not trying to simultaneously subscribe and send.
         */
        let autoconnected = await subject.asyncPublisher()
            .map { $0 % 47 }
            .autoconnect()

        let n = 100

        let counter1 = Counter()
        let box1 = MutableBox<[Int]>.init(value: [])
        let p1 = await autoconnected.asyncPublisher().sink { result in
            switch result {
                case let .value(value):
                    counter1.increment()
                    var l = box1.value
                    l.append(value)
                    box1.set(value: l)
                    return
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
                    return
                case .completion(.finished):
                    let count = counter1.count
                    if count != n {
                        print(box1.value)
                        XCTFail("Incorrect count: \(count) in subscription 1")
                    }
                    return
            }
        }

        let p2 = await autoconnected.asyncPublisher().sink { result in
            switch result {
                case .value:
                    return
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
                    return
                case .completion(.finished):
                    return
            }
        }

        for i in (0 ..< n) {
            do { try await subject.send(i) }
            catch { XCTFail("Failed to send on \(i)") }
        }

        try await subject.finish()
        _ = await p1.result
        _ = await p2.result
        _ = await subject.result
        _ = await autoconnected.result
    }
}
