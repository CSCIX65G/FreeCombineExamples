//
//  FutureFoldTests.swift
//  
//
//  Created by Van Simmons on 9/13/22.
//
import XCTest
@testable import Future

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

    // The following two tests verify that the ordering of the fold
    // is correct regardless of the order of promise completion
    // and that all promises are running in parallel
    func testAsyncFoldOrdering() async throws {
        var others = [AsyncPromise<Int>]()
        for _ in (0 ..< 10) {
            let p = await AsyncPromise<Int>()
            others.append(p)
        }
        let this = Succeeded(0)
        let folded = this.fold(futures: others.map(\.future)) { accum, num in
            Succeeded(num - accum)
        }

        (1 ..< 11)
            .map { i in {
                do { try others[i - 1].succeed(i) }
                catch { XCTFail("Failed with error: \(error)") }
            } }
            .shuffled()
            .forEach { $0() }

        let cancellable = await folded.sink { value in
            guard case let .success(value) = value else {
                XCTFail("Received failure: \(value)")
                return
            }
            XCTAssert(value == 5, "Received wrong value: \(value)")
        }
        _ = await cancellable.result
    }

    func testAsyncFoldOrderingReversed() async throws {
        var others = [AsyncPromise<Int>]()
        for _ in (0 ..< 10) {
            let p = await AsyncPromise<Int>()
            others.append(p)
        }
        let this = Succeeded(0)
        let folded = this.fold(futures: others.map(\.future)) { accum, num in
            Succeeded(num - accum)
        }

        (1 ..< 11)
            .map { i in {
                do { try others[i - 1].succeed(11 - i) }
                catch { XCTFail("Failed with error: \(error)") }
            } }
            .shuffled()
            .forEach { $0() }

        let cancellable = await folded.sink { value in
            guard case let .success(value) = value else {
                XCTFail("Received failure: \(value)")
                return
            }
            XCTAssert(value == -5, "Received wrong value: \(value)")
        }
        _ = await cancellable.result
    }

    func testAsyncFoldFailure() async throws {
        enum Error: Swift.Error, Equatable {
            case iFailed
        }
        var others = [AsyncPromise<Int>]()
        for _ in (0 ..< 10) {
            let p = await AsyncPromise<Int>()
            others.append(p)
        }
        let this = Succeeded(0)
        let folded = this.fold(futures: others.map(\.future)) { accum, num in
            Succeeded(num - accum)
        }

        do { try others.randomElement()!.fail(Error.iFailed) }
        catch { XCTFail("failed to fail") }

        let cancellable = await folded.sink { value in
            guard case let .failure(rawError) = value else {
                XCTFail("Received success: \(value)")
                return
            }
            let error = rawError as? Error
            XCTAssert(error != .none, "Wrong error type for error: \(rawError)")
        }
        _ = await cancellable.result
    }
}
