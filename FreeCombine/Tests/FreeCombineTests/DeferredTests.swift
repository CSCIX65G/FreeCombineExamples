//
//  DeferTests.swift
//
//
//  Created by Van Simmons on 2/12/22.
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

class DeferTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testSimpleDeferred() async throws {
        let expectation1 = await Promise<Void>()
        let expectation2 = await Promise<Void>()

        let count1 = Counter()
        let p =  UnfoldedSequence("abc")

        let d1 = Deferred { p }
        let d2 = Deferred { p }

        let c1 = await d1.sink ({ result in
            switch result {
                case .value:
                    count1.increment()
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
                case .completion(.finished):
                    let count = count1.count
                    XCTAssert(count == 3, "wrong number of values sent: \(count)")
                    do {
                        try expectation1.succeed()
                        _ = await expectation1.result
                    } catch {
                        XCTFail("Failed to complete")
                    }
                    throw Publishers.Error.done
            }
            return
        })

        let count2 = Counter()
        let c2 = await d2.sink { result in
            switch result {
                case .value:
                    count2.increment()
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
                case .completion(.finished):
                    let count = count2.count
                    XCTAssert(count == 3, "wrong number of values sent: \(count)")
                    do {
                        try expectation2.succeed()
                        _ = await expectation2.result
                    } catch {
                        XCTFail("Failed to complete")
                    }
                    throw Publishers.Error.done
            }
            return
        }

        do {  _ = try await c1.value }
        catch {
            guard let error = error as? Publishers.Error, case error = Publishers.Error.done else {
                XCTFail("Failed with: \(error)")
                return
            }
        }
        do {  _ = try await c2.value }
        catch {
            guard let error = error as? Publishers.Error, case error = Publishers.Error.done else {
                XCTFail("Failed with: \(error)")
                return
            }
        }
    }

    func testDeferredDefer() async throws {
        let expectation1 = await Promise<Void>()
        let expectation2 = await Promise<Void>()

        let count1 = Counter()
        let p = Deferred {
            UnfoldedSequence("abc")
        }
        let d1 = Deferred { p }
        let d2 = Deferred { p }

        let c1 = await d1.sink ({ result in
            switch result {
                case .value:
                    count1.increment()
                    return
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
                    throw Publishers.Error.done
                case .completion(.finished):
                    let count = count1.count
                    XCTAssert(count == 3, "wrong number of values sent: \(count)")
                    do {
                        try expectation1.succeed()
                        _ = await expectation1.result
                    }
                    catch { XCTFail("Failed to complete") }
                    throw Publishers.Error.done
            }
        })

        let count2 = Counter()
        let c2 = await d2.sink { result in
            switch result {
                case .value:
                    count2.increment()
                    return
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
                    throw Publishers.Error.done
                case .completion(.finished):
                    let count = count2.count
                    XCTAssert(count == 3, "wrong number of values sent: \(count)")
                    do {
                        try expectation2.succeed()
                        _ = await expectation2.result
                    }
                    catch { XCTFail("Failed to complete") }
                    throw Publishers.Error.done
            }
        }

        do {  _ = try await c1.value }
        catch {
            guard let error = error as? Publishers.Error, case error = Publishers.Error.done else {
                XCTFail("Failed with: \(error)")
                return
            }
        }
        do {  _ = try await c2.value }
        catch {
            guard let error = error as? Publishers.Error, case error = Publishers.Error.done else {
                XCTFail("Failed with: \(error)")
                return
            }
        }
    }
}
