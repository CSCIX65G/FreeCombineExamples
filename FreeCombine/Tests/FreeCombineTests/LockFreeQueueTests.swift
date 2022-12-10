//
//  LockFreeQueueTests.swift
//  
//
//  Created by Van Simmons on 12/9/22.
//
import XCTest
@testable import Core
@testable import Channel

import XCTest

final class LockFreeQueueTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testLockFreeQueueMultiProducer() async throws {
        let queue = LockFreeQueue<Int>()
        let cancellables: [Cancellable<Void>] = (0 ..< 1_000).map { _ in
            .init {
                (0 ..< 10).forEach { queue.enqueue($0) }
            }
        }
        (0 ..< 10_000).forEach { _ in
            guard let i = queue.dequeue() else {
                XCTFail("Queue exhausted early")
                return
            }
            XCTAssert(i >= 0 && i < 1_000, "Invalid value")
        }
        guard queue.dequeue() == nil else {
            XCTFail("too many values")
            return
        }
        cancellables.forEach { try? $0.cancel() }
    }
}
