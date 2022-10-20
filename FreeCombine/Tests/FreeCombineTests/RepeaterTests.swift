//
//  RepeaterTests.swift
//  
//
//  Created by Van Simmons on 10/17/22.
//

import XCTest
@testable import FreeCombine

final class RepeaterTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testSimpleRepeater() async throws {
        let returnChannel = Channel<Repeater<Int, String>.ResultAndNext>.init(buffering: .bufferingOldest(1))
//        var resumption: 

        let (initialResumption, repeater) = await Repeater.repeater(
            dispatch: { String.init($0) },
            returnChannel: returnChannel
        )

        for i in 0 ..< 1000 {

        }

        _ = await repeater.cancellable.result
    }
}
