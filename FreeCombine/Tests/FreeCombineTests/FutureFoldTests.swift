//
//  FutureFoldTests.swift
//  
//
//  Created by Van Simmons on 9/13/22.
//

import XCTest
@testable import FreeCombine

final class FutureFoldTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testSimpleFold() async throws {
        let others = (1 ..< 11).map { Succeeded($0) }
        let this = Succeeded("0")
        let folded = this.fold(futures: others) { str, num in
            Succeeded(str + "\(num)")
        }
        let cancellable = await folded.sink { _ in }
        _ = await cancellable.result
    }
}
