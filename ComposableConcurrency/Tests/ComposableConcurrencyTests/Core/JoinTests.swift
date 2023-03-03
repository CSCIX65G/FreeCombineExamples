//
//  JoinTests.swift
//  
//
//  Created by Van Simmons on 11/18/22.
//

import XCTest
@testable import Core
@testable import Future

final class JoinTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws {  }

    func testSimpleCancellableJoin() async throws {
        let expectation = await AsyncPromise<Void>()
        let canCan: Cancellable<Cancellable<Void>> = .init {
            .init {
                try await withTaskCancellationHandler(
                    operation: { try await expectation.value },
                    onCancel: { try? expectation.fail(CancellationError()) }
                )
            }
        }

        let c1 = canCan.join()
        try? c1.cancel()
        let _ = await c1.result
    }
}
