//
//  MulticastTests.swift
//  
//
//  Created by Van Simmons on 12/9/22.
//

@testable import Core
@testable import Future
@testable import Publisher

import XCTest

final class MulticastTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testSimpleMulticast() async throws {
        let promise1 = AsyncPromise<Void>()
        let promise2 = AsyncPromise<Void>()

        let n = 100
        let subject = PassthroughSubject(Int.self)

        let counter1 = Counter()
        let u1 = await subject.asyncPublisher().sink { (result: Publisher<Int>.Result) in
            switch result {
                case .value:
                    counter1.increment()
                    if counter1.count == n {
                        do { try promise1.succeed() }
                        catch { XCTFail("Failed to complete with error: \(error)") }
                    }
                    return
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
                    return
                case .completion(.finished):
                    let count = counter1.count
                    guard count == 100 else {
                        XCTFail("Incorrect count: \(count) in subscription 1")
                        return
                    }
                    return
            }
        }

        let counter2 = Counter()
        let u2 = await subject.asyncPublisher().sink { (result: Publisher<Int>.Result) in
            switch result {
                case .value:
                    counter2.increment()
                    if counter2.count == n {
                        do { try promise2.succeed() }
                        catch { XCTFail("Failed to complete with error: \(error)") }
                    }
                    return
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
                    return
                case .completion(.finished):
                    let count = counter2.count
                    guard count == 100 else {
                        XCTFail("Incorrect count: \(count) in subscription 2")
                        return
                    }
                    return
            }
        }

        let upstreamCounter = Counter()
        let upstreamShared = MutableBox<Bool>(value: false)
        let connectable = await (0 ..< n)
            .asyncPublisher
            .handleEvents(
                receiveDownstream: { _ in
                    Task<Void, Swift.Error> {
                        guard upstreamShared.value == false else {
                            XCTFail("Shared more than once")
                            return
                        }
                        upstreamShared.set(value: true)
                    }
                },
                receiveOutput: { _ in
                    upstreamCounter.increment()
                },
                receiveFinished: {
                    let count = upstreamCounter.count
                    XCTAssert(count == n, "Wrong number sent")
                },
                receiveFailure: { error in
                    XCTFail("Inappropriately failed with: \(error)")
                }
            )
            .multicast(subject)

        try await connectable.connect()
        
        _ = await promise1.result
        _ = await promise2.result

        _ = try await subject.finish()

        _ = try await u1.value
        _ = try await u2.value

        let _ = await subject.result
    }

    func testSubjectMulticast() async throws {
        let subj = PassthroughSubject(Int.self)
        let upstream = PassthroughSubject(Int.self)
        let connectable = await upstream.asyncPublisher().multicast(subj)

        let n = 100

        let counter1 = Counter()
        let u1 = await subj.asyncPublisher().sink { result in
            switch result {
                case .value:
                    counter1.increment()
                    return
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
                    return
                case .completion(.finished):
                    let count = counter1.count
                    if count != 100 {
                        XCTFail("Incorrect count: \(count) in subscription 1")
                    }
                    return
            }
        }

        let counter2 = Counter()
        let u2 = await subj.asyncPublisher().sink { (result: Publisher<Int>.Result) in
            switch result {
                case .value:
                    counter2.increment()
                    return
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
                    return
                case .completion(.finished):
                    let count = counter2.count
                    if count != n  {
                        XCTFail("Incorrect count: \(count) in subscription 2")
                    }
                    return
            }
        }

        try await connectable.connect()

        for i in (0 ..< n) {
            do { try await upstream.send(i) }
            catch { XCTFail("Failed to send on \(i) with error: \(error)") }
        }
        
        try? await upstream.finish()
        _ = await upstream.result

        try? await subj.finish()
        _ = await subj.result

        _ = await connectable.result
        _ = try await u1.value
        _ = try await u2.value

    }
}
