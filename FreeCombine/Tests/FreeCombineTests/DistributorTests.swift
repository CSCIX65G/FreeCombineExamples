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
        let distributor = Distributor<Int>()
        let subscription = try await distributor.subscribe(operation: { result in
            switch result {
                case .completion(.failure(let error)):
                    XCTFail("Received failure: \(error)")
                default:
                    ()
            }
        })

        try distributor.send(0)
        _ = await distributor.finish()
        _ = await distributor.result
        _ = await subscription.result
    }
}
