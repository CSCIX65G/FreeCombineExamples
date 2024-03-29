//
//  FlatMapTests.swift
//
//
//  Created by Van Simmons on 5/19/22.
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

class FlatMapTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testSimpleFlatMap() async throws {
        let expectation = AsyncPromise<Void>()

        let checksum = Counter()
        let c1 = await UnfoldedSequence(0 ... 3)
            .map { $0 * 2 }
            .flatMap { (value) -> Publisher<Int> in
                [Int].init(repeating: value, count: value).asyncPublisher
            }
            .sink { result in
                switch result {
                    case let .value(value):
                        checksum.increment(by: value)
                        return
                    case let .completion(.failure(error)):
                        XCTFail("Got an error? \(error)")
                        throw Publishers.Error.done
                    case .completion(.finished):
                        let value = checksum.count
                        XCTAssert(value == 56, "Did not get all values")
                        do {
                            try expectation.succeed()
                            _ = await expectation.result
                        } catch {
                            XCTFail("Should not have failed promise")
                        }
                        throw Publishers.Error.done
                }
            }

        let _ = await c1.result
    }
}
