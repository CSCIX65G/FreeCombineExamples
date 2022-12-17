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
        let promise1 = await Promise<Void>()
        let promise2 = await Promise<Void>()

        let subject = PassthroughSubject(Int.self)

        let counter1 = Counter()
        let u1 = await subject.asyncPublisher.sink { (result: Publisher<Int>.Result) in
            switch result {
                case .value:
                    counter1.increment()
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
                    do { try promise1.succeed() }
                    catch { XCTFail("Failed to complete with error: \(error)") }
                    return
            }
        }

        let counter2 = Counter()
        let u2 = await subject.asyncPublisher.sink { (result: Publisher<Int>.Result) in
            switch result {
                case .value:
                    counter2.increment()
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
                    do { try promise2.succeed() }
                    catch { XCTFail("Failed to complete with error: \(error)") }
                    return
            }
        }

        let n = 100
        let upstreamCounter = Counter()
        let upstreamShared = MutableBox<Bool>(value: false)
        let connectable = (0 ..< n)
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

        _ = await connectable.connect()

        _ = try await u1.value
        _ = try await u2.value

        let _ = try await subject.value
    }

    func testSubjectMulticast() async throws {
        let subj = PassthroughSubject(Int.self)
        let upstream = PassthroughSubject(Int.self)
        let connectable = upstream.asyncPublisher.multicast(subj)

        let counter1 = Counter()
        let u1 = await subj.asyncPublisher.sink { result in
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
        let u2 = await subj.asyncPublisher.sink { (result: Publisher<Int>.Result) in
            switch result {
                case .value:
                    counter2.increment()
                    return
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
                    return
                case .completion(.finished):
                    let count = counter2.count
                    if count != 100  {
                        XCTFail("Incorrect count: \(count) in subscription 2")
                    }
                    return
            }
        }

        await connectable.connect()

        for i in (0 ..< 100) {
            do { try await upstream.send(i) }
            catch { XCTFail("Failed to send on \(i) with error: \(error)") }
        }
        try? await upstream.finish()
        _ = await upstream.result

        _ = await connectable.result
        _ = try await u1.value
        _ = try await u2.value
        try? await subj.finish()
        _ = await subj.result
    }
}
