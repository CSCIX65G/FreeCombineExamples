//
//  SubjectTests.swift
//
//
//  Created by Van Simmons on 5/13/22.
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

class SubjectTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

//    func testSimpleSubject() async throws {
//        let expectation = await Promise<Void>()
//
//        let subject = try await CurrentValueSubject(currentValue: 14)
//        let publisher = subject.publisher
//
//        let counter = Counter()
//        let c1 = await publisher.sink { (result: Publisher<Int>.Result) in
//            let count = counter.count
//            switch result {
//                case .value:
//                    _ = counter.increment()
//                    return
//                case let .completion(.failure(error)):
//                    XCTFail("Got an error? \(error)")
//                    throw Publishers.Error.done
//                case .completion(.finished):
//                    XCTAssert(count == 5, "wrong number of values sent: \(count)")
//                    do {
//                        try await expectation.complete()
//                    }
//                    catch {
//                        XCTFail("Failed to complete: \(error)")
//                    }
//                    throw Publishers.Error.done
//                case .completion(.cancelled):
//                    XCTFail("Should not have cancelled")
//                    throw Publishers.Error.done
//            }
//        }
//        do {
//            try await subject.send(14)
//            try await subject.send(15)
//            try await subject.send(16)
//            try await subject.send(17)
//            try await subject.finish()
//        } catch {
//            XCTFail("Caught error: \(error)")
//        }
//
//        do { _ =
//            try await subject.value
//            let demand = try await c1.value
//            XCTAssert(demand == .done, "Did not finish correctly")
//        }
//        catch { XCTFail("Should not have thrown") }
//        do { _ = try await expectation.value }
//        catch {
//            let count = counter.count
//            XCTFail("Timed out, count = \(count)")
//        }
//
//        _ = await c1.result
//    }
//
//    func testMultisubscriptionSubject() async throws {
//        let expectation1 = await Promise<Void>()
//        let expectation2 = await Promise<Void>()
//
//        let subject = try await CurrentValueSubject(currentValue: 14)
//        let publisher = subject.publisher
//
//        let counter1 = Counter()
//        let c1 = await publisher.sink { (result: Publisher<Int>.Result) in
//            let count = counter1.count
//            switch result {
//                case .value:
//                    _ = counter1.increment()
//                    return
//                case let .completion(.failure(error)):
//                    XCTFail("Got an error? \(error)")
//                    throw Publishers.Error.done
//                case .completion(.finished):
//                    XCTAssert(count == 5, "wrong number of values sent: \(count)")
//                    do { try await expectation1.complete() }
//                    catch { XCTFail("Failed to complete: \(error)") }
//                    throw Publishers.Error.done
//                case .completion(.cancelled):
//                    XCTFail("Should not have cancelled")
//                    throw Publishers.Error.done
//            }
//        }
//
//        let counter2 = Counter()
//        let c2 = await publisher.sink { (result: Publisher<Int>.Result) in
//            let count = counter2.count
//            switch result {
//                case .value:
//                    _ = counter2.increment()
//                    return
//                case let .completion(.failure(error)):
//                    XCTFail("Got an error? \(error)")
//                    throw Publishers.Error.done
//                case .completion(.finished):
//                    XCTAssert(count == 5, "wrong number of values sent: \(count)")
//                    do { try await expectation2.complete() }
//                    catch { XCTFail("Failed to complete: \(error)") }
//                    throw Publishers.Error.done
//                case .completion(.cancelled):
//                    XCTFail("Should not have cancelled")
//                    throw Publishers.Error.done
//            }
//        }
//
//        do {
//            try await subject.send(14)
//            try await subject.send(15)
//            try await subject.send(16)
//            try await subject.send(17)
//            try await subject.finish()
//        } catch {
//            XCTFail("Caught error: \(error)")
//        }
//
//        do { _ =
//            try await subject.value
//            let demand1 = try await c1.value
//            XCTAssert(demand1 == .done, "Did not finish c1 correctly")
//            let demand2 = try await c2.value
//            XCTAssert(demand2 == .done, "Did not finish c2 correctly")
//        }
//        catch { XCTFail("Should not have thrown") }
//
//        do {
//            _ = try await expectation1.value
//            _ = try await expectation2.value
//        }
//        catch {
//            XCTFail("Timed out, count1 = \(counter1.count), count2 = \(counter2.count)")
//        }
//        _ = await c1.result
//        _ = await c2.result
//    }
//
//    func testSimpleCancellation() async throws {
//        let counter = Counter()
//        let expectation = await Promise<Void>()
//        let expectation3 = await Promise<Void>()
//        let release = await Promise<Void>()
//
//        let subject = try await PassthroughSubject(Int.self)
//        let p = subject.publisher
//
//        let can = await p.sink({ result in
//            switch result {
//                case let .value(value):
//                    let count = counter.increment()
//                    XCTAssertEqual(value, count, "Wrong value sent")
//                    if count == 8 {
//                        do {
//                            try await expectation.complete()
//                            return
//                        }
//                        catch {
//                            XCTFail("failed to complete")
//                        }
//                        do {
//                            try await release.value
//                            return
//                        } catch {
//                            guard let error = error as? PublisherError, case error = PublisherError.cancelled else {
//                                XCTFail("Timed out waiting for release")
//                                throw Publishers.Error.done
//                            }
//                        }
//                    } else if count > 8 {
//                        XCTFail("Got value after cancellation")
//                        throw Publishers.Error.done
//                    }
//                    return
//                case let .completion(.failure(error)):
//                    XCTFail("Should not have gotten error: \(error)")
//                    throw Publishers.Error.done
//                case .completion(.finished):
//                    XCTFail("Should not have finished")
//                    throw Publishers.Error.done
//                case .completion(.cancelled):
//                    try await expectation3.complete()
//                    throw Publishers.Error.done
//            }
//        })
//
//        for i in 1 ... 7 {
//            do { try await subject.send(i) }
//            catch { XCTFail("Failed to enqueue") }
//        }
//
//        do { try await subject.send(8) }
//        catch { XCTFail("Failed to enqueue") }
//
//        do { _ = try await expectation.value }
//        catch { XCTFail("Failed waiting for expectation") }
//
//        let _ = can.cancel()
//
//        try await release.complete()
//        do { _ = try await expectation3.value }
//        catch { XCTFail("Failed waiting for expectation3") }
//
//        do {
//            try await subject.send(9)
//            try await subject.send(10)
//        } catch {
//            XCTFail("Failed to enqueue")
//        }
//        try await subject.finish()
//        _ = await subject.result
//    }
//
//    func testSimpleTermination() async throws {
//        let counter = Counter()
//        let expectation = await Promise<Void>()
//
//        let subject = try await PassthroughSubject(Int.self)
//        let p = subject.publisher
//
//        let c1 = await p.sink( { result in
//            switch result {
//                case let .value(value):
//                    let count = counter.increment()
//                    XCTAssertEqual(value, count, "Wrong value sent")
//                    return
//                case let .completion(.failure(error)):
//                    XCTFail("Should not have gotten error: \(error)")
//                    throw Publishers.Error.done
//                case .completion(.finished):
//                    do { try await expectation.complete() }
//                    catch { XCTFail("Failed to complete expectation") }
//                    let count = counter.count
//                    XCTAssert(count == 1000, "Received wrong number of invocations: \(count)")
//                    throw Publishers.Error.done
//                case .completion(.cancelled):
//                    XCTFail("Should not have cancelled")
//                    throw Publishers.Error.done
//            }
//        })
//
//        for i in 1 ... 1000 {
//            do { try await subject.send(i) }
//            catch { XCTFail("Failed to enqueue") }
//        }
//        try await subject.finish()
//
//        do { _ = try await expectation.value }
//        catch {
//            let count = counter.count
//            XCTFail("Timed out waiting for expectation.  processed: \(count)")
//        }
//        _ = await c1.result
//        _ = await subject.result
//    }
//
//    func testSimpleSubjectSend() async throws {
//        let counter = Counter()
//        let expectation = await Promise<Void>()
//
//        let subject = try await PassthroughSubject(Int.self)
//        let p = subject.publisher()
//
//        let c1 = await p.sink({ result in
//            switch result {
//                case let .value(value):
//                    let count = counter.increment()
//                    XCTAssertEqual(value, count, "Wrong value sent")
//                    return
//                case let .completion(.failure(error)):
//                    XCTFail("Should not have gotten error: \(error)")
//                    throw Publishers.Error.done
//                case .completion(.finished):
//                    do { try await expectation.complete() }
//                    catch { XCTFail("Could not complete, error: \(error)") }
//                    let count = counter.count
//                    XCTAssert(count == 5, "Received wrong number of invocations: \(count)")
//                    throw Publishers.Error.done
//                case .completion(.cancelled):
//                    XCTFail("Should not have cancelled")
//                    throw Publishers.Error.done
//            }
//        })
//
//        for i in (1 ... 5) {
//            do { try await subject.send(i) }
//            catch { XCTFail("Failed to enqueue") }
//        }
//        try await subject.finish()
//
//        do { _ = try await expectation.value }
//        catch {
//            let count = counter.count
//            XCTFail("Timed out waiting for expectation.  processed: \(count)")
//        }
//        _ = await c1.result
//        _ = await subject.result
//    }
//
//    func testSyncAsync() async throws {
//        let expectation = await Promise<Void>()
//        let fsubject1 = try await PassthroughSubject(Int.self)
//        let fsubject2 = try await PassthroughSubject(String.self)
//
//        let fseq1 = "abcdefghijklmnopqrstuvwxyz".publisher
//        let fseq2 = (1 ... 100).publisher
//
//        let fz1 = fseq1.zip(fseq2)
//        let fz2 = fz1.map { left, right in String(left) + String(right) }
//
//        let fm1 = fsubject1.publisher()
//            .map(String.init)
//            .merge(with: fsubject2.publisher())
//
//        let counter = Counter()
//        let c1 = await fz2
//            .merge(with: fm1)
//            .sink({ value in
//                switch value {
//                    case .value(_):
//                        counter.increment()
//                        return
//                    case let .completion(.failure(error)):
//                        XCTFail("Should not have received failure: \(error)")
//                        throw Publishers.Error.done
//                    case .completion(.finished):
//                        let count = counter.count
//                        if count != 28  { XCTFail("Incorrect number of values") }
//                        try await expectation.complete()
//                        throw Publishers.Error.done
//                    case .completion(.cancelled):
//                        XCTFail("Should not have cancelled")
//                        throw Publishers.Error.done
//                }
//            })
//
//        try await fsubject1.send(14)
//        try await fsubject2.send("hello, combined world!")
//
//        try await fsubject1.finish()
//        try await fsubject2.finish()
//
//        do { _ = try await expectation.value }
//        catch {
//            XCTFail("timed out")
//        }
//        do { _ = try await c1.value }
//        catch { XCTFail("Should have completed normally") }
//
//        _ = await fsubject1.result
//        _ = await fsubject2.result
//
//    }
}
