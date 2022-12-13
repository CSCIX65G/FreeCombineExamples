//
//  LockFreeQueueTests.swift
//  
//
//  Created by Van Simmons on 12/9/22.
//
import XCTest
@testable import Core
@testable import Queue


final class LockFreeQueueTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testLockFreeQueueMultiProducer() async throws {
        let queue = LockFreeQueue<Int>()
        let cancellables: [Cancellable<Void>] = (0 ..< 100).map { _ in
            .init {
                for i in (0 ..< 10) {
                    guard !Cancellables.isCancelled else { return }
                    queue.enqueue(i)
                    await Task.yield()
                }
            }
        }
        var failureCount = 0
        for j in (0 ..< 1_000) {
            while failureCount < 100_000 {
                if let i = queue.dequeue() {
                    XCTAssert(i >= 0 && i < 1_000, "Invalid value")
                    break
                } else {
                    failureCount += 1
                }
                await Task.yield()
            }
            if failureCount >= 10_000 {
                XCTFail("Queue exhausted early, j = \(j)")
                break
            }
        }
        guard queue.dequeue() == nil else {
            XCTFail("too many values")
            return
        }
        cancellables.forEach { try? $0.cancel() }
    }
}
