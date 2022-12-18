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
@testable import Core
@testable import Future
@testable import Publisher

class SubjectTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testSimpleCancellation() async throws {
        let counter = Counter()
        let expectation = await Promise<Void>()
        let expectation3 = await Promise<Void>()
        let release = await Promise<Void>()

        let subject = PassthroughSubject(Int.self)
        let p = subject.asyncPublisher()

        let can = await p.sink { result in
            switch result {
                case let .value(value):
                    let count = counter.increment()
                    XCTAssertEqual(value, count, "Wrong value sent")
                    if count == 8 {
                        do { try expectation.succeed() }
                        catch {  XCTFail("failed to complete") }
                        do {
                            return try await release.value
                        }
                        catch {
                            guard let _ = error as? CancellationError else {
                                XCTFail("Timed out waiting for release")
                                return
                            }
                        }
                    } else if count > 8 {
                        XCTFail("Got value after cancellation")
                        return
                    }
                    return
                case let .completion(.failure(error)):
                    guard let _ = error as? CancellationError else {
                        XCTFail("Should not have gotten error: \(error)")
                        return
                    }
                    do { try expectation3.succeed() }
                    catch { XCTFail("failed to release main thread")

                    }
                    return
                case .completion(.finished):
                    XCTFail("Should not have finished")
                    return
            }
        }

        for i in 1 ... 7 {
            do { try await subject.send(i) }
            catch { XCTFail("Failed to enqueue") }
        }

        do { try subject.yield(8) }
        catch { XCTFail("Failed to enqueue") }

        do { _ = try await expectation.value }
        catch { XCTFail("Failed waiting for expectation") }

        do {
            let _ = try can.cancel()
        }
        catch { XCTFail("Failed to cancel") }

        do {
            try release.succeed()
        }
        catch { XCTFail("Failed to release post cancel") }

        do { _ = try await expectation3.value }
        catch { XCTFail("Failed waiting for expectation3") }

        do {
            try await subject.send(9)
            try await subject.send(10)
        } catch {
            XCTFail("Failed to enqueue")
        }
        try await subject.finish()
        _ = await subject.result
    }

    func testSimpleTermination() async throws {
        let counter = Counter()
        let expectation = await Promise<Void>()

        let subject = PassthroughSubject(Int.self)
        let p = subject.asyncPublisher()

        let c1 = await p.sink { result in
            switch result {
                case let .value(value):
                    let count = counter.increment()
                    XCTAssertEqual(value, count, "Wrong value sent")
                    return
                case let .completion(.failure(error)):
                    XCTFail("Should not have gotten error: \(error)")
                    return
                case .completion(.finished):
                    do { try expectation.succeed() }
                    catch { XCTFail("Failed to complete expectation") }
                    let count = counter.count
                    XCTAssert(count == 1000, "Received wrong number of invocations: \(count)")
                    return
            }
        }

        for i in 1 ... 1000 {
            do { try await subject.send(i) }
            catch { XCTFail("Failed to enqueue") }
        }
        try await subject.finish()

        do { _ = try await expectation.value }
        catch {
            let count = counter.count
            XCTFail("Timed out waiting for expectation.  processed: \(count)")
        }
        _ = await c1.result
        _ = await subject.result
    }

    func testSimpleSubjectSend() async throws {
        let counter = Counter()
        let expectation = await Promise<Void>()

        let subject = PassthroughSubject(Int.self)
        let p = subject.asyncPublisher()

        let c1 = await p.sink { result in
            switch result {
                case let .value(value):
                    let count = counter.increment()
                    XCTAssertEqual(value, count, "Wrong value sent")
                    return
                case let .completion(.failure(error)):
                    XCTFail("Should not have gotten error: \(error)")
                    return
                case .completion(.finished):
                    do { try expectation.succeed() }
                    catch { XCTFail("Could not complete, error: \(error)") }
                    let count = counter.count
                    XCTAssert(count == 5, "Received wrong number of invocations: \(count)")
                    return
            }
        }

        for i in (1 ... 5) {
            do { try await subject.send(i) }
            catch { XCTFail("Failed to enqueue") }
        }
        try await subject.finish()

        do { _ = try await expectation.value }
        catch {
            let count = counter.count
            XCTFail("Timed out waiting for expectation.  processed: \(count)")
        }
        _ = await c1.result
        _ = await subject.result
    }

    func testSyncAsync() async throws {
        let expectation = await Promise<Void>()
        let fsubject1 = PassthroughSubject(Int.self)
        let fsubject2 = PassthroughSubject(String.self)

        let fseq1 = "abcdefghijklmnopqrstuvwxyz".asyncPublisher
        let fseq2 = (1 ... 100).asyncPublisher

        let fz1 = fseq1.zip(fseq2)
        let fz2 = fz1.map { left, right in String(left) + String(right) }

        let fm1 = fsubject1.asyncPublisher()
            .map(String.init)
            .merge(with: fsubject2.asyncPublisher())

        let counter = Counter()
        let c1 = await fz2
            .merge(with: fm1)
            .sink { value in
                switch value {
                    case .value(_):
                        counter.increment()
                        return
                    case let .completion(.failure(error)):
                        XCTFail("Should not have received failure: \(error)")
                        return
                    case .completion(.finished):
                        let count = counter.count
                        if count != 28  { XCTFail("Incorrect number of values") }
                        try expectation.succeed()
                        return
                }
            }

        try await fsubject1.send(14)
        try await fsubject2.send("hello, combined world!")

        try await fsubject1.finish()
        try await fsubject2.finish()

        do { _ = try await expectation.value }
        catch {
            XCTFail("timed out")
        }
        do { _ = try await c1.value }
        catch { XCTFail("Should have completed normally") }

        _ = await fsubject1.result
        _ = await fsubject2.result

    }

    func testSimpleSubject() async throws {
        let expectation = await Promise<Void>()

        let subject = CurrentValueSubject(14)
        let publisher = subject.asyncPublisher()

        let counter = Counter()
        let c1 = await publisher.sink { (result: Publisher<Int>.Result) in
            let count = counter.count
            switch result {
                case .value:
                    _ = counter.increment()
                    return
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
                    throw Publishers.Error.done
                case .completion(.finished):
                    XCTAssert(count == 5, "wrong number of values sent: \(count)")
                    do {
                        try expectation.succeed()
                    }
                    catch {
                        XCTFail("Failed to complete: \(error)")
                    }
                    throw Publishers.Error.done
            }
        }
        do {
            try await subject.send(14)
            try await subject.send(15)
            try await subject.send(16)
            try await subject.send(17)
            try await subject.finish()
        } catch {
            XCTFail("Caught error: \(error)")
        }

        do { _ =
            try await subject.value
            _ = try await c1.value
        }
        catch { }
        do { _ = try await expectation.value }
        catch {
            let count = counter.count
            XCTFail("Timed out, count = \(count)")
        }

        _ = await c1.result
    }

    func testMultisubscriptionSubject() async throws {
        let expectation1 = await Promise<Void>()
        let expectation2 = await Promise<Void>()

        let subject = CurrentValueSubject(13)
        let publisher = subject.asyncPublisher()

        let counter1 = Counter()
        let c1 = await publisher.sink { (result: Publisher<Int>.Result) in
            let count = counter1.count
            switch result {
                case .value:
                    _ = counter1.increment()
                    return
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
                    throw Publishers.Error.done
                case .completion(.finished):
                    XCTAssert(count == 5, "wrong number of values sent: \(count)")
                    do { try expectation1.succeed() }
                    catch { XCTFail("Failed to complete: \(error)") }
                    throw Publishers.Error.done
            }
        }

        let counter2 = Counter()
        let c2 = await publisher.sink { (result: Publisher<Int>.Result) in
            let count = counter2.count
            switch result {
                case .value:
                    _ = counter2.increment()
                    return
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
                    throw Publishers.Error.done
                case .completion(.finished):
                    XCTAssert(count == 5, "wrong number of values sent: \(count)")
                    do { try expectation2.succeed() }
                    catch { XCTFail("Failed to complete: \(error)") }
                    throw Publishers.Error.done
            }
        }

        do {
            try await subject.send(14)
            try await subject.send(15)
            try await subject.send(16)
            try await subject.send(17)
            try await subject.finish()
        } catch {
            XCTFail("Caught error: \(error)")
        }

        do { _ =
            try await subject.value
            try await c1.value
            try await c2.value
        }
        catch {
            XCTFail("Should not have thrown: \(error)")
        }

        do {
            _ = try await expectation1.value
            _ = try await expectation2.value
        }
        catch {
            XCTFail("Timed out, count1 = \(counter1.count), count2 = \(counter2.count)")
        }
        _ = await c1.result
        _ = await c2.result
    }
}
