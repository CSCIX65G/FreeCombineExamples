//
//  DistributorTests.swift
//  
//
//  Created by Van Simmons on 10/18/22.
//

import XCTest
@testable import FreeCombine

final class DistributorTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testSimpleDistributor() async throws {
        let numValues = 100
        let distributor = Distributor<Int>(buffering: .bufferingOldest(100))
        let subscription = try await distributor.subscribe(operation: { result in
            switch result {
                case .completion(.failure(let error)):
                    XCTFail("Received failure: \(error)")
                default:
                    ()
            }
        })

        (0 ..< numValues).forEach { i in
            do { try distributor.send(i) }
            catch { XCTFail("Could not enqueue: \(error)") }
        }
        _ = await distributor.finish()
        _ = await distributor.result
        _ = await subscription.result
    }

    func testMultipleDistributor() async throws {
        let numValues = 100, numSubscriptions = 100
        let distributor = Distributor<Int>(buffering: .bufferingOldest(100))
        let counter = Counter()

        var subscriptions: [Cancellable<Void>] = []
        for _ in 0 ..< numSubscriptions {
            guard let subscription = (try? await distributor.subscribe(operation: { result in
                switch result {
                    case .completion(.failure(let error)):
                        XCTFail("Received failure: \(error)")
                    default:
                        counter.increment()
                }
            } ) ) else {
                XCTFail("Could not create subscription")
                return
            }
            subscriptions.append(subscription)
        }
        XCTAssert(subscriptions.count == 100, "Could not create subscriptions")

        (0 ..< numValues).forEach { i in
            do { try distributor.send(i) }
            catch { XCTFail("Could not enqueue: \(error)") }
        }
        _ = await distributor.finish()
        _ = await distributor.result
        for i in 0 ..< numSubscriptions {
            _ = await subscriptions[i].result
        }
        XCTAssert(counter.count == (numValues + 1) * numSubscriptions, "Incorrect number of values repeated: \(counter.count)")
    }

    func testMultipleAsyncSendDistributor() async throws {
        let numValues = 100, numSubscriptions = 100
        let distributor = Distributor<Int>(buffering: .bufferingOldest(100))
        let counter = Counter()

        var subscriptions: [Cancellable<Void>] = []
        for _ in 0 ..< numSubscriptions {
            guard let subscription = (try? await distributor.subscribe(operation: { result in
                switch result {
                    case .completion(.failure(let error)):
                        XCTFail("Received failure: \(error)")
                    default:
                        counter.increment()
                }
            } ) ) else {
                XCTFail("Could not create subscription")
                return
            }
            subscriptions.append(subscription)
        }
        XCTAssert(subscriptions.count == 100, "Could not create subscriptions")

        for i in 0 ..< numValues {
            do { try await distributor.send(i) }
            catch { XCTFail("Could not enqueue: \(error)") }
        }
        _ = await distributor.finish()
        _ = await distributor.result
        for i in 0 ..< numSubscriptions {
            _ = await subscriptions[i].result
        }
        XCTAssert(counter.count == (numValues + 1) * numSubscriptions, "Incorrect number of values repeated: \(counter.count)")
    }
}
