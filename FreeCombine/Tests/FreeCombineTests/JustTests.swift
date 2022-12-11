//
//  JustTests.swift
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

class JustTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testSimpleSynchronousJust() async throws {
        let expectation1 = await Promise<Void>()
        let expectation2 = await Promise<Void>()

        let just = Just(7)

        let c1 = await just.sink { (result: Publisher<Int>.Result) in
            switch result {
                case let .value(value):
                    XCTAssert(value == 7, "wrong value sent: \(value)")
                    return
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
                    throw Publishers.Error.done
                case .completion(.finished):
                    do { try expectation1.succeed() }
                    catch { XCTFail("Failed to complete with error: \(error)") }
                    throw Publishers.Error.done
            }
        }

        let c2 = await just.sink { (result: Publisher<Int>.Result) in
            switch result {
                case let .value(value):
                    XCTAssert(value == 7, "wrong value sent: \(value)")
                    return
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
                    throw Publishers.Error.done
                case .completion(.finished):
                    do { try expectation2.succeed() }
                    catch { XCTFail("Failed to complete with error: \(error)") }
                    throw Publishers.Error.done
            }
        }

        do {
            _ = try await expectation1.value
            _ = try await expectation2.value
        } catch {
            XCTFail("Expectations threw")
        }
        let _ = await c1.result
        let _ = await c2.result
    }

    func testSimpleSequenceJust() async throws {
        let expectation1 = await Promise<Void>()
        let just = Just([1, 2, 3, 4])
        let c1 = await just.sink { (result: Publisher<[Int]>.Result) in
            switch result {
                case let .value(value):
                    XCTAssert(value == [1, 2, 3, 4], "wrong value sent: \(value)")
                    return
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
                    throw Publishers.Error.done
                case .completion(.finished):
                    do { try expectation1.succeed() }
                    catch {
                        XCTFail("Failed to complete with error: \(error)")
                    }
                    throw Publishers.Error.done
            }
        }
        do {
            _ = try await c1.value
        } catch {
            guard let error = error as? Publishers.Error, case error = Publishers.Error.done else {
                XCTFail("Did not complete, error = \(error)")
                return
            }
        }
        do { _ = try await expectation1.value }
        catch { XCTFail("Timed out") }
    }

    func testSimpleAsyncJust() async throws {
        let expectation1 = await Promise<Void>()
        let expectation2 = await Promise<Void>()

        let just = Just(7)

        let c1 = await just.sink { (result: Publisher<Int>.Result) in
            switch result {
                case let .value(value):
                    XCTAssert(value == 7, "wrong value sent: \(value)")
                    return
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
                    throw Publishers.Error.done
                case .completion(.finished):
                    do { try expectation1.succeed() }
                    catch { XCTFail("Failed to complete with error: \(error)") }
                    throw Publishers.Error.done
            }
        }

        var t: Cancellable<Void>! = .none
        do { _ = try await pause { resumption in
            t = just.sink(onStartup: resumption, { result in
                switch result {
                    case let .value(value):
                        XCTAssert(value == 7, "wrong value sent: \(value)")
                        return
                    case let .completion(.failure(error)):
                        XCTFail("Got an error? \(error)")
                        throw Publishers.Error.done
                    case .completion(.finished):
                        do { try expectation2.succeed() }
                        catch {
                            XCTFail("Failed to complete with error: \(error)")
                        }
                        throw Publishers.Error.done
                }
            } )
        } } catch {
            XCTFail("Resumption failed")
        }

        do {
            _ = try await t.value
        } catch {
            guard let error = error as? Publishers.Error, case error = Publishers.Error.done else {
                XCTFail("Did not complete, error = \(error)")
                return
            }
        }
        do {
            _ = try await expectation1.value
            _ = try await expectation2.value
        } catch {
            XCTFail("Timed out")
        }

        let _ = await c1.result
    }
}
