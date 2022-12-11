//
//  MulticastTests.swift
//  
//
//  Created by Van Simmons on 12/9/22.
//

@testable import Core
@testable import Future
@testable import Publisher
@testable import FreeCombine

import XCTest

final class MulticastTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testSimpleMulticast() async throws {
        let promise1 = await Promise<Void>()
        let promise2 = await Promise<Void>()

        let subject = try await PassthroughSubject(Int.self)

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
        let shared = await (0 ..< n)
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
            .sink { value in  }

        _ = try await u1.value
        _ = try await u2.value

        let _ = try await subject.value
        let _ = try await shared.value
    }

//    func testSubjectMulticast() async throws {
//        let subj = try await PassthroughSubject(Int.self)
//
//        let connectable = try await subj
//            .publisher()
//            .map { $0 }
//            .makeConnectable()
//
//        let counter1 = Counter()
//        let u1 = await connectable.publisher().sink({ result in
//            switch result {
//                case .value:
//                    counter1.increment()
//                    return .more
//                case let .completion(.failure(error)):
//                    XCTFail("Got an error? \(error)")
//                    return .done
//                case .completion(.finished):
//                    let count = counter1.count
//                    if count != 100 {
//                        XCTFail("Incorrect count: \(count) in subscription 1")
//                    }
//                    return .done
//                case .completion(.cancelled):
//                    XCTFail("Should not have cancelled")
//                    return .done
//            }
//        })
//
//        let counter2 = Counter()
//        let u2 = await connectable.publisher().sink { (result: AsyncStream<Int>.Result) in
//            switch result {
//                case .value:
//                    counter2.increment()
//                    return .more
//                case let .completion(.failure(error)):
//                    XCTFail("Got an error? \(error)")
//                    return .done
//                case .completion(.finished):
//                    let count = counter2.count
//                    if count != 100  {
//                        XCTFail("Incorrect count: \(count) in subscription 2")
//                    }
//                    return .done
//                case .completion(.cancelled):
//                    XCTFail("Should not have cancelled")
//                    return .done
//            }
//        }
//
//        try await connectable.connect()
//
//        for i in (0 ..< 100) {
//            do { try await subj.blockingSend(i) }
//            catch { XCTFail("Failed to send on \(i) with error: \(error)") }
//        }
//
//        try await subj.finish()
//        _ = await subj.result
//        _ = await connectable.result
//        let d1 = try await u1.value
//        XCTAssert(d1 == .done, "First chain has wrong value")
//        let d2 = try await u2.value
//        XCTAssert(d2 == .done, "Second chain has wrong value")
//    }
}
