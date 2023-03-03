//
//  MapTests.swift
//
//
//  Created by Van Simmons on 3/16/22.
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

class MapTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testSimplePublisherMap() async throws {
        let expectation1 = await AsyncPromise<Void>()

        let just = Just(7)

        let m1 = await just
            .map { $0 * 2 }
            .sink { result in
                switch result {
                    case let .value(value):
                        XCTAssert(value == 14, "wrong value sent: \(value)")
                        return
                    case let .completion(.failure(error)):
                        XCTFail("Got an error? \(error)")
                        throw Publishers.Error.done
                    case .completion(.finished):
                        do {
                            try expectation1.succeed()
                            _ = await expectation1.result
                        }
                        catch { XCTFail("Failed to complete with error: \(error)") }
                        throw Publishers.Error.done
                }
            }

        do { _ = try await expectation1.value }
        catch { XCTFail("Timed out") }

        _ = await m1.result
    }
}
