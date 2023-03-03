//
//  FutureTests.swift
//
//
//  Created by Van Simmons on 8/15/22.
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
@testable import Future

final class FutureTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testSimpleFutureToPublisher() async throws {
        let expectation = AsyncPromise<Void>()
        let promise = AsyncPromise<Int>()
        let cancellation = await promise.future
            .sink { result in
                do { try expectation.succeed() }
                catch { XCTFail("Failed completion expecation with: \(error)") }
                return
            }

        try promise.succeed(13)
        _ = await cancellation.result
    }
}
