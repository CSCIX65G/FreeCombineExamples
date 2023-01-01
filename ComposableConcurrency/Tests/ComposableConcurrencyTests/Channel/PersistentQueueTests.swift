//
//  PersistentQueueTests.swift
//  
//
//  Created by Van Simmons on 12/31/22.
//

import XCTest
@testable import Channel

final class PersistentQueueTests: XCTestCase {

    override func setUpWithError() throws { }
    override func tearDownWithError() throws { }

    func testSimplePersistentQueue() throws {
        let size = 1_000
        var queue = PersistentQueue<Int>()
        for i in 0 ..< size {
            XCTAssert(queue.count == i, "Wrong enqueue count: \(queue.count), should be: \(i)")
            queue = queue.enqueue(i)
        }
        XCTAssert(queue.count == size, "Wrong queued count: \(queue.count)")

        for i in 0 ..< size {
            XCTAssert(queue.count == size - i, "Wrong dequeue: \(queue.count), should be: \(size - i)")
            let (head, newQueue) = queue.dequeue()
            queue = newQueue
            XCTAssert(head == i, "Wrong head: \(head ?? Int.max), should be: \(i)")
        }

        for i in 0 ..< size {
            XCTAssert(queue.count == i, "Wrong enqueue count: \(queue.count), should be: \(i)")
            queue = queue.enqueue(i)
        }
        XCTAssert(queue.range.upperBound == size, "did not reset range at empty, range = \(queue.range)")
    }
}
