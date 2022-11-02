//
//  RepeaterTests.swift
//  
//
//  Created by Van Simmons on 10/17/22.
//

import XCTest
@testable import FreeCombine

final class RepeaterTests: XCTestCase {
    typealias ID = Int
    typealias Arg = Int
    typealias Return = String

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    enum TestError: Error {
        case finished
        case failure(Error)
    }

    @Sendable func dispatch(_ result: Publisher<Int>.Result) async throws -> String {
        switch result {
            case let .value(value):
                return .init(value)
            case .completion(.finished):
                throw TestError.finished
            case .completion(.failure(let error)):
                throw TestError.failure(error)
        }
    }

    func testSimpleRepeater() async throws {
        let returnChannel = Channel<ConcurrentFunc<Arg, Return>.Next>.init(buffering: .bufferingOldest(1))

        let first = await ConcurrentFunc<Arg, Return>.Invocation(
            dispatch: self.dispatch,
            returnChannel: returnChannel
        )
        let cancellable = Cancellable<Void> {
            let max = 10_000
            var i = 0
            first.resumption.resume(returning: .value(i))
            for await next in returnChannel.stream {
                guard case let .success(returnValue) = next.result, returnValue == String(i) else {
                    XCTFail("incorrect value: \(next.result)")
                    return
                }
                i += 1
                if i == max {
                    next.invocation.resumption.resume(throwing: CancellationError())
                    returnChannel.finish()
                } else {
                    next.invocation.resumption.resume(returning: .value(i))
                }
            }
            return
        }
        _ = await cancellable.result
        _ = await first.function.cancellable.result
    }

    func testMultipleRepeaters() async throws {
        let numRepeaters = 100, numValues = 100
        let returnChannel = Channel<ConcurrentFunc<Arg, Return>.Next>.init(buffering: .bufferingOldest(numRepeaters))
        let cancellable: Cancellable<Void> = .init {
            var iterator = returnChannel.stream.makeAsyncIterator()
            var functions: [ObjectIdentifier: ConcurrentFunc<Arg, Return>.Invocation] = [:]
            for _ in 0 ..< numRepeaters {
                let first = await ConcurrentFunc.Invocation(
                    dispatch: self.dispatch,
                    returnChannel: returnChannel
                )
                functions[first.function.id] = .init(function: first.function, resumption: first.resumption)
            }
            for i in 0 ..< numValues {
                // Send the values
                for (_, pair) in functions {
                    pair.resumption.resume(returning: .value(i))
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
                    guard let function = functions[next.id]?.function else {
                        XCTFail("Lost function")
                        return
                    }
                    functions[next.id] = .init(function: function, resumption: next.invocation.resumption)
                }
            }
            // Close everything
            for (_, invocation) in functions {
                invocation.resumption.resume(throwing: CancellationError())
                _ = await invocation.function.cancellable.result
            }
        }
        _ = await cancellable.result
    }
}
