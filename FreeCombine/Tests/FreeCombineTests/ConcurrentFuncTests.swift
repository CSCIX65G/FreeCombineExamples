//
//  RepeaterTests.swift
//  
//
//  Created by Van Simmons on 10/17/22.
//

import XCTest
@testable import FreeCombine

fileprivate typealias TestArg = Int
fileprivate typealias TestReturn = String

fileprivate enum TestError: Error {
    case finished
    case failure(Error)
}

@Sendable fileprivate func dispatch(_ result: Publisher<TestArg>.Result) async throws -> TestReturn {
    switch result {
        case let .value(value):
            return .init(value)
        case .completion(.finished):
            throw TestError.finished
        case .completion(.failure(let error)):
            throw TestError.failure(error)
    }
}

final class ConcurrentFuncTests: XCTestCase {
    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testSimpleConcurrentFunc() async throws {
        let returnChannel = Channel<ConcurrentFunc<TestArg, TestReturn>.Next>.init(buffering: .bufferingOldest(1))

        let f = await ConcurrentFunc<TestArg, TestReturn>(dispatch)
        let cancellable = Cancellable<Void> {
            var iterator = returnChannel.stream.makeAsyncIterator()
            do { try f(returnChannel: returnChannel, .value(14)) }
            catch { XCTFail("Should not have failed with error: \(error)") }
            guard let next = await iterator.next() else {
                XCTFail("No result")
                return
            }
            switch next.result {
                case let .success(value): XCTAssert(value == "14", "Incorrect value: \(value)")
                case let .failure(error): XCTFail("Received error: \(error)")
            }
            do { try next.concurrentFunc(returnChannel: returnChannel, .completion(.finished)) }
            catch { XCTFail("failed to complete") }
            returnChannel.finish()
            guard await iterator.next() == nil else {
                XCTFail("did not complete")
                return
            }
        }

        _ = await cancellable.result
    }

    func testSimpleRepeater() async throws {
        let returnChannel = Channel<ConcurrentFunc<TestArg, TestReturn>.Next>.init(buffering: .bufferingOldest(1))

        let first = await ConcurrentFunc(dispatch)
        let cancellable = Cancellable<Void> {
            let max = 10_000
            var i = 0
            //first.value(i))
            do { try first(returnChannel: returnChannel, .value(i)) }
            catch { XCTFail("Failed on first send, i = \(i)"); return }
            for await next in returnChannel.stream {
                guard case let .success(returnValue) = next.result, returnValue == String(i) else {
                    XCTFail("incorrect value: \(next.result)")
                    return
                }
                i += 1
                if i == max {
                    next.concurrentFunc.resumption.resume(throwing: CancellationError())
                    returnChannel.finish()
                } else {
                    do { try next.concurrentFunc(returnChannel: returnChannel, .value(i)) }
                    catch { XCTFail("Failed sending \(i)"); return }
                }
            }
            return
        }
        _ = await cancellable.result
        _ = await first.dispatch.cancellable.result
    }

    func testMultipleRepeaters() async throws {
        let numRepeaters = 100, numValues = 100
        let returnChannel = Channel<ConcurrentFunc<TestArg, TestReturn>.Next>.init(buffering: .bufferingOldest(numRepeaters))
        let cancellable: Cancellable<Void> = .init {
            var iterator = returnChannel.stream.makeAsyncIterator()
            var functions: [ObjectIdentifier: ConcurrentFunc<TestArg, TestReturn>] = [:]
            for _ in 0 ..< numRepeaters {
                let first = await ConcurrentFunc(dispatch)
                functions[first.id] = .init(
                    dispatch: first.dispatch,
                    resumption: first.resumption
                )
            }
            for i in 0 ..< numValues {
                // Send the values
                for (_, concurrentFunc) in functions {
                    do { try concurrentFunc(returnChannel: returnChannel, .value(i)) }
                    catch { XCTFail("Failed dispatching \(i)"); return }
                }
                // Gather the returns
                for _ in 0 ..< numRepeaters {
                    guard let next = await iterator.next() else {
                        XCTFail("Ran out of values")
                        return
                    }
                    guard case let .success(value) = next.result else {
                        XCTFail("Encountered failure")
                        return
                    }
                    guard value == String(i) else {
                        XCTFail("Incorrect value")
                        return
                    }
                    guard let function = functions[next.id]?.dispatch else {
                        XCTFail("Lost function")
                        return
                    }
                    functions[next.id] = .init(dispatch: function, resumption: next.concurrentFunc.resumption)
                }
            }
            // Close everything
            for (_, invocation) in functions {
                invocation.resumption.resume(throwing: CancellationError())
                _ = await invocation.dispatch.cancellable.result
            }
        }
        _ = await cancellable.result
    }
}
