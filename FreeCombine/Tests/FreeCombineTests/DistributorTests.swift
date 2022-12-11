//
//  DistributorTests.swift
//  
//
//  Created by Van Simmons on 10/18/22.
//

import XCTest
@testable import Core
@testable import Publisher

final class DistributorTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testSimpleDistributor() async throws {
        let numValues = 100
        let distributor: Distributor<Int> = .init(buffering: .bufferingOldest(100))
        let subscription = try await distributor.subscribe(operation: { result in
            switch result {
                case .completion(.failure(let error)):
                    XCTFail("Received failure: \(error)")
                default:
                    ()
            }
        })

        for i in 0 ..< numValues {
            do { try await distributor.send(i) }
            catch { XCTFail("Could not enqueue: \(error)") }
        }
        _ = try await distributor.finish()

        let subscriptionResult = await subscription.result
        guard case .success = subscriptionResult else {
            XCTFail("Should not have received failure: \(subscriptionResult)")
            return
        }
    }

    func testMultipleDistributor() async throws {
        let numValues = 100, numSubscriptions = 100
        let distributor = Distributor<Int>(buffering: .bufferingOldest(100))
        let counter = Counter()

        var subscriptions: [Cancellable<Void>] = []
        for _ in 0 ..< numSubscriptions {
            guard let subscription = (try? await distributor.subscribe(operation: { result in
                switch result {
                    case .completion(.finished):
                        counter.increment()
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
        _ = try await distributor.finish()
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
            guard let subscription = (try? await distributor.subscribe { result in
                switch result {
                    case .completion(.failure(let error)):
                        XCTFail("Received failure: \(error)")
                    default:
                        counter.increment()
                }
            } ) else {
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
        _ = try await distributor.finish()
        for i in 0 ..< numSubscriptions {
            _ = await subscriptions[i].result
        }
        XCTAssert(counter.count == (numValues + 1) * numSubscriptions, "Incorrect number of values repeated: \(counter.count)")
    }

    func testUnsubscribeDistributor() async throws {
        let numValues = Int.random(in: 10 ..< 100)
        let numSubscriptions = Int.random(in: 10 ..< 50)
        let unsubscribeAfter = Int.random(in: 0 ..< numValues)
        let numUnsubscriptions = Int.random(in: 0 ... numSubscriptions)

        let distributor = Distributor<Int>(buffering: .bufferingOldest(numValues))
        let counter = Counter()

        var subscriptions: [Cancellable<Void>] = []
        for _ in 0 ..< numSubscriptions {
            guard let subscription = (try? await distributor.subscribe { result in
                switch result {
                    case .completion(.failure(let error)) where !(error is CancellationError):
                        XCTFail("Received failure: \(error)")
                    default:
                        counter.increment()
                }
            } ) else {
                XCTFail("Could not create subscription")
                return
            }
            subscriptions.append(subscription)
        }
        XCTAssert(subscriptions.count == numSubscriptions, "Could not create subscriptions")

        for i in 0 ..< numValues {
            if i == unsubscribeAfter {
                for _ in 0 ..< numUnsubscriptions {
                    let c = subscriptions.remove(at: Int.random(in: 0 ..< subscriptions.count))
                    try! c.cancel()
                    _ = await c.result
                }
            }
            do { try await distributor.send(i) }
            catch { XCTFail("Could not enqueue: \(error)") }
        }
        _ = try await distributor.finish()
        for i in 0 ..< subscriptions.count {
            _ = await subscriptions[i].result
        }
        let expectedCount = ((numValues + 1) * numSubscriptions)
        - (numUnsubscriptions * (numValues - unsubscribeAfter))
        let count = counter.count
        XCTAssert(counter.count == expectedCount,
                  """
                  Incorrect number of values for:
                  numValues = \(numValues),
                  numSubscriptions = \(numSubscriptions),
                  unsubscribeAfter = \(unsubscribeAfter)
                  numUnsubscriptions = \(numUnsubscriptions)
                  Expected: \(expectedCount)
                  Got: \(count)
                  """
        )
    }

    struct RandomError: Error { }

    func testRandomizedDistributorOperations() async throws {
        let numValues = Int.random(in: 0 ..< 100)

        let distributor = Distributor<Int>(buffering: .bufferingOldest(1))
        let counter = Counter()

        var subscriptions: [Cancellable<Void>] = []

        for i in 0 ..< numValues {
            if UInt8.random(in: 0 ..< 3) == 0 {
                guard let subscription = (try? await distributor.subscribe { result in
                    switch result {
                        case .completion(.failure(let error)) where !(error is CancellationError):
                            XCTFail("Received failure: \(error)")
                        default:
                            if UInt8.random(in: 0 ..< 5) == 0 { throw RandomError() }
                    }
                } ) else {
                    XCTFail("Could not create subscription")
                    return
                }
                subscriptions.append(subscription)
            }
            if subscriptions.count > 0, UInt8.random(in: 0 ..< 3) == 0 {
                let c = subscriptions.remove(at: Int.random(in: 0 ..< subscriptions.count))
                try? c.cancel()
                _ = await c.result
            }
            do {
                try await distributor.send(i)
                counter.increment()
            }
            catch {
                XCTFail("Could not enqueue: \(error)")
            }
        }
        _ = try await distributor.finish()
        for i in 0 ..< subscriptions.count {
            _ = await subscriptions[i].result
        }
        let count = counter.count
        XCTAssert(count == numValues,
           """
           Incorrect number of values for:
           numValues = \(numValues),
           Got: \(count)
           """
        )
    }
}
