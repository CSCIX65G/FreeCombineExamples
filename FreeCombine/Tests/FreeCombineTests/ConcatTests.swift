//
//  ConcatTests.swift
//
//
//  Created by Van Simmons on 2/4/22.
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

class ConcatTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testSimpleConcat() async throws {
        let expectation = await Promise<Void>()

        let publisher1 = "0123456789".asyncPublisher
        let publisher2 = "abcdefghijklmnopqrstuvwxyz".asyncPublisher
        let publisher3 = "ZYXWVU".asyncPublisher

        let count = Counter()
        let c1 = await Concat(publisher1, publisher2, publisher3)
            .sink { result in
                switch result {
                    case .value:
                        count.increment()
                        return .more
                    case let .completion(.failure(error)):
                        XCTFail("Got an error? \(error)")
                        return .done
                    case .completion(.finished):
                        let n = count.count
                        XCTAssert(n == 42, "wrong number of values sent: \(n)")
                        do {
                            try expectation.succeed()
                        } catch {
                            XCTFail("Could not complete: \(error)")
                        }
                        return .done
                }
            }

        do {  _ = try await c1.value }
        catch { XCTFail("Should have completed") }
    }

    func testMultiConcat() async throws {
        let expectation1 = await Promise<Void>()
        let expectation2 = await Promise<Void>()

        let publisher1 = "0123456789".asyncPublisher
        let publisher2 = "abcdefghijklmnopqrstuvwxyz".asyncPublisher
        let publisher3 = "ZYXWVU".asyncPublisher

        let publisher = Concat(publisher1, publisher2, publisher3)

        let count1 = Counter()
        let c1 = await publisher
            .sink { result in
                switch result {
                    case .value:
                        count1.increment()
                        return .more
                    case let .completion(.failure(error)):
                        XCTFail("Got an error? \(error)")
                        return .done
                    case .completion(.finished):
                        let count = count1.count
                        XCTAssert(count == 42, "wrong number of values sent: \(count)")
                        do {
                            try expectation1.succeed()
                        } catch {
                            XCTFail("Failed to complete branch 1: \(error)")
                        }
                        return .done
                }
            }

        let count2 = Counter()
        let c2 = await publisher
            .sink { result in
                switch result {
                    case .value:
                        count2.increment()
                        return .more
                    case let .completion(.failure(error)):
                        XCTFail("Got an error? \(error)")
                        return .done
                    case .completion(.finished):
                        let count = count2.count
                        XCTAssert(count == 42, "wrong number of values sent: \(count)")
                        do {
                            try expectation2.succeed()
                        } catch {
                            XCTFail("Failed to complete branch 2: \(error)")
                        }
                        return .done
                }
            }

        do {
            _ = try await c1.value
            _ = try await c2.value
        }
        catch { XCTFail("Should have completed") }
    }
}
