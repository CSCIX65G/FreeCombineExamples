//
//  PromiseTests.swift
//  UsingFreeCombineTests
//
//  Created by Van Simmons on 9/5/22.
//

import XCTest
@testable import Core
@testable import FreeCombine

final class PromiseTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testPromiseSuccess() async throws {
        let promise: Promise<Int> = await .init()
        let c: Cancellable<Void> = .init(operation: {
            do { try promise.succeed(13) }
            catch { XCTFail("Could not complete") }
        })
        switch await promise.result {
            case .success(let value):
                XCTAssert(value == 13, "Got the wrong value")
            case .failure(let error):
                XCTFail("Got an error: \(error)")
        }
        _ = await c.result
    }

    func testPromiseFailure() async throws {
        enum Error: Swift.Error, Equatable {
            case iFailed
        }
        let promise: Promise<Int> = await .init()
        let c: Cancellable<Void> = .init(operation: {
            do { try promise.fail(Error.iFailed) }
            catch { XCTFail("Could not complete") }
        })
        switch await promise.result {
            case .success(let value):
                XCTFail("Failed by succeeding with value: \(value)")
            case .failure(let error):
                guard let _ = error as? Error else {
                    XCTFail("Wrong error type")
                    return
                }
        }
        _ = await c.result
    }

    func testSimplePromise() async throws {
        let expectation = await Promise<Void>()
        let promise = await Promise<Int>()
        let cancellation = await promise.future
            .sink ({ result in
                do { try expectation.succeed() }
                catch { XCTFail("Failed to complete with error: \(error)") }
                switch result {
                    case .success(let value):
                        XCTAssert(value == 13, "Wrong value")
                    case .failure(let error):
                        XCTFail("Failed with \(error)")
                }
            })

        try promise.succeed(13)

        do { _ = try await expectation.value }
        catch { XCTFail("Timed out") }

        _ = await cancellation.result
    }

    func testSimpleFailedPromise() async throws {
        enum PromiseError: Error, Equatable {
            case iFailed
        }
        let expectation = await Promise<Void>()
        let promise = await Promise<Int>()
        let cancellation = await promise.future
            .sink { result in
                do { try expectation.succeed() }
                catch { XCTFail("Failed to complete with error: \(error)") }
                switch result {
                    case .success(let value):
                        XCTFail("Got a value \(value)")
                    case .failure(let error):
                        guard let e = error as? PromiseError, e == .iFailed else {
                            XCTFail("Wrong error: \(error)")
                            return
                        }
                }
            }

        try promise.fail(PromiseError.iFailed)

        do {  _ = try await expectation.value }
        catch { XCTFail("Timed out") }

        _ = await cancellation.result
    }

    func testMultipleSubscribers() async throws {
        let promise = await Promise<Int>()
        let max = 1_000
        let range = 0 ..< max

        var pairs: [(Promise<Void>, Cancellable<Void>)] = .init()
        for _ in range {
            let expectation = await Promise<Void>()
            let cancellation = await promise.future
                .map { $0 * 2 }
                .sink ({ result in
                    do { try expectation.succeed() }
                    catch { XCTFail("Failed to complete with error: \(error)") }
                    switch result {
                        case .success(let value): XCTAssert(value == 26, "Wrong value")
                        case .failure(let error): XCTFail("Failed with \(error)")
                    }
                })
            let pair = (expectation, cancellation)
            pairs.append(pair)
        }
        XCTAssertTrue(pairs.count == max, "Failed to create futures")
        try promise.succeed(13)

        do {
            for pair in pairs {
                _ = try await pair.0.value
                _ = await pair.1.result
            }
        } catch {
            XCTFail("Timed out")
        }
    }

//    func testMultipleSends() async throws {
//        let promise = await Promise<Int>()
//        let max = 1_000
//        let range = 0 ..< max
//
//        var pairs: [(Promise<Void>, Cancellable<Void>)] = .init()
//        for _ in range {
//            let expectation = await Promise<Void>()
//            let cancellation = await promise.future
//                .map { $0 * 2 }
//                .sink ({ result in
//                    do { try expectation.succeed() }
//                    catch { XCTFail("Failed to complete with error: \(error)") }
//                    switch result {
//                        case .success(let value): XCTAssert(value == 26, "Wrong value")
//                        case .failure(let error): XCTFail("Failed with \(error)")
//                    }
//                })
//            let pair = (expectation, cancellation)
//            pairs.append(pair)
//        }
//        let succeedCounter = Counter()
//        let failureCounter = Counter()
//        XCTAssertTrue(pairs.count == max, "Failed to create futures")
//        let maxAttempts = 100
//        let _: Void = try await withResumption { resumption in
//            let semaphore: FreeCombine.Semaphore<Void, Void> = .init(
//                resumption: resumption,
//                reducer: { _, _ in return },
//                initialState: (),
//                count: maxAttempts
//            )
//            for _ in 0 ..< maxAttempts {
//                Task {
//                    do { try await promise.succeed(13); succeedCounter.increment(); await semaphore.decrement(with: ()) }
//                    catch { failureCounter.increment(); await semaphore.decrement(with: ()) }
//                }
//            }
//        }
//        let successCount = succeedCounter.count
//        XCTAssert(successCount == 1, "Too many successes")
//
//        let failureCount = failureCounter.count
//        XCTAssert(failureCount == maxAttempts - 1, "Too few failures")
//
//        do {
//            for pair in pairs {
//                _ = try await pair.0.value
//                _ = await pair.1.result
//            }
//        } catch {
//            XCTFail("Timed out")
//        }
//    }
}
