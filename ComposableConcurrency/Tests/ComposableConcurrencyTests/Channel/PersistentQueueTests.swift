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
            let (_, newQueue) = queue.enqueue(i)
            queue = newQueue
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
            let (_, newQueue) = queue.enqueue(i)
            queue = newQueue
        }
        XCTAssert(queue.range.upperBound == size, "did not reset range at empty, range = \(queue.range)")
    }

    func testFixedSizePersistentQueueNewest() throws {
        let size = 50
        let bufferSize = 10
        var queue = PersistentQueue<Int>(buffering: .newest(bufferSize))
        for i in 0 ..< size {
            if i < bufferSize {
                XCTAssert(queue.count == i, "Wrong enqueue count: \(queue.count), should be: \(i)")
            } else {
                XCTAssert(queue.count == bufferSize, "Wrong enqueue count: \(queue.count), should be: \(bufferSize)")
            }
            let (_, newQueue) = queue.enqueue(i)
            queue = newQueue
        }
        XCTAssert(queue.count == bufferSize, "Wrong queued count: \(queue.count)")

        for i in 0 ..< bufferSize {
            XCTAssert(queue.count == bufferSize - i, "Wrong dequeue: \(queue.count), should be: \(bufferSize - i)")
            let (head, newQueue) = queue.dequeue()
            queue = newQueue
            XCTAssert(head == size - bufferSize + i, "Wrong head: \(head ?? Int.max), should be: \(i)")
        }
        XCTAssert(queue.range.upperBound == 0, "did not reset range at empty, range = \(queue.range)")

        for i in 0 ..< bufferSize {
            XCTAssert(queue.count == i, "Wrong enqueue count: \(queue.count), should be: \(i)")
            let (_, newQueue) = queue.enqueue(i)
            queue = newQueue
        }
        XCTAssert(queue.range.upperBound == bufferSize, "did not reset range at empty, range = \(queue.range)")
    }

    func testFixedSizePersistentQueueOldest() throws {
        let size = 50
        let bufferSize = 10
        var queue = PersistentQueue<Int>(buffering: .oldest(bufferSize))
        for i in 0 ..< size {
            if i < bufferSize {
                XCTAssert(queue.count == i, "Wrong enqueue count: \(queue.count), should be: \(i)")
            } else {
                XCTAssert(queue.count == bufferSize, "Wrong enqueue count: \(queue.count), should be: \(bufferSize)")
            }
            let (_, newQueue) = queue.enqueue(i)
            queue = newQueue
        }
        XCTAssert(queue.count == bufferSize, "Wrong queued count: \(queue.count)")

        for i in 0 ..< bufferSize {
            XCTAssert(queue.count == bufferSize - i, "Wrong dequeue: \(queue.count), should be: \(bufferSize - i)")
            let (head, newQueue) = queue.dequeue()
            queue = newQueue
            XCTAssert(head == i, "Wrong head: \(head ?? Int.max), should be: \(i)")
        }
        XCTAssert(queue.range.upperBound == 0, "did not reset range at empty, range = \(queue.range)")

        for i in 0 ..< bufferSize {
            XCTAssert(queue.count == i, "Wrong enqueue count: \(queue.count), should be: \(i)")
            let (_, newQueue) = queue.enqueue(i)
            queue = newQueue
        }
        XCTAssert(queue.range.upperBound == bufferSize, "did not reset range at empty, range = \(queue.range)")
    }

    func testSequenceInit() throws {
        let minVal = 1_000_000
        let maxVal = 1_000_050
        let sequence: any Sequence<Int> = minVal ..< maxVal
        let bufferSize = 10
        var queue = PersistentQueue<Int>(buffering: .newest(bufferSize), sequence)
        XCTAssert(queue.count == bufferSize, "Wrong queued count: \(queue.count)")

        for i in 0 ..< bufferSize {
            XCTAssert(queue.count == bufferSize - i, "Wrong dequeue: \(queue.count), should be: \(bufferSize - i)")
            let (head, newQueue) = queue.dequeue()
            queue = newQueue
            XCTAssert(head == maxVal - bufferSize + i, "Wrong head: \(head ?? Int.max), should be: \(maxVal - bufferSize + i)")
        }
        XCTAssert(queue.range.upperBound == 0, "did not reset range at empty, range = \(queue.range)")
    }

    func testRandomAccessCollectionInit() throws {
        let minVal = 1_000_000
        let maxVal = 1_000_050
        let sequence: [Int] = (minVal ..< maxVal).map { $0 }
        let bufferSize = 10
        var queue = PersistentQueue<Int>(buffering: .newest(bufferSize), sequence)
        XCTAssert(queue.count == bufferSize, "Wrong queued count: \(queue.count)")

        for i in 0 ..< bufferSize {
            XCTAssert(queue.count == bufferSize - i, "Wrong dequeue: \(queue.count), should be: \(bufferSize - i)")
            let (head, newQueue) = queue.dequeue()
            queue = newQueue
            XCTAssert(head == maxVal - bufferSize + i, "Wrong head: \(head ?? Int.max), should be: \(maxVal - bufferSize + i)")
        }
        XCTAssert(queue.range.upperBound == 0, "did not reset range at empty, range = \(queue.range)")
    }
}
