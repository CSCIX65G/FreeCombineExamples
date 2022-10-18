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
        let dispatchChannel = Channel<Distributor<Int>.DownstreamDispatch>(buffering: .bufferingOldest(1))
        let returnChannel = Channel<Distributor<Int>.DownstreamReturn>.init(buffering: .bufferingOldest(1))

        let repeater = Distributor<Int>.Repeater.init(
            streamId: 0,
            dispatchChannel: dispatchChannel,
            returnChannel: returnChannel
        )

        var dispatchCancellable: Cancellable<Void>!
        let _: Void = try await withResumption { resumption in
            dispatchCancellable = .init {
                resumption.resume()
                for await (_, nextResumption) in dispatchChannel.stream {
                    do { try nextResumption.tryResume(returning: .success(())) }
                    catch { XCTFail("DispatchCancellable threw error: \(error)") }
                }
            }
        }

        let numberOfValues = 1_000
        var returnCancellable: Cancellable<Void>!
        let _: Void = try await withResumption { resumption in
            returnCancellable = Cancellable<Void> {
                var value = 0
                resumption.resume()
                for await (_, result, nextResumption) in returnChannel.stream {
                    guard let nextResumption = nextResumption else { return }
                    repeater.dispatchReturn = nextResumption
                    guard case .success = result else {
                        XCTFail("Unexpected failure")
                        dispatchChannel.finish()
                        break
                    }
                    let dispatchValue: Distributor<Int>.DownstreamDispatch = (value, nextResumption)
                    do { try dispatchChannel.tryYield(dispatchValue) }
                    catch { XCTFail("Return cancellable threw: \(error)") }
                    value += 1
                    if value > numberOfValues {
                        dispatchChannel.finish()
                        break
                    }
                }
            }
        }

        _ = await dispatchCancellable.result
        _ = await returnCancellable.result
    }
}
