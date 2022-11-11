//
//  DropFirstTests.swift
//
//
//  Created by Van Simmons on 6/4/22.
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

class DropFirstTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testSimpleDropFirst() async throws {
        let expectation1 = await Promise<Void>()
        let unfolded = (0 ..< 100).asyncPublisher

        let counter1 = Counter()
        let u1 = await unfolded
            .dropFirst(27)
            .sink { (result: Publisher<Int>.Result) in
            switch result {
                case .value:
                    counter1.increment()
                    return
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
                    throw Publishers.Error.done
                case .completion(.finished):
                    let count = counter1.count
                    guard count == 73 else {
                        XCTFail("Incorrect count: \(count) in subscription 1")
                        throw Publishers.Error.done
                    }
                    do { try expectation1.succeed() }
                    catch { XCTFail("Failed to complete with error: \(error)") }
                    throw Publishers.Error.done
            }
        }
        do {  _ = try await expectation1.value }
        catch { XCTFail("Timed out") }

        do {
            let finalValue = try await u1.value
        } catch {
            guard let error = error as? Publishers.Error, case error = Publishers.Error.done else {
                XCTFail("Did not complete, error = \(error)")
                return
            }
        }
    }
}
