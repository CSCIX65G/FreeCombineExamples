//
//  SelectTests.swift
//  
//
//  Created by Van Simmons on 11/12/22.
//

import XCTest
@testable import Core
@testable import Future
@testable import Publisher
@testable import SendableAtomics

final class SelectTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testSimpleSelect() async throws {
        let expectation = AsyncPromise<Void>()

        let publisher1 = (0 ... 13).asyncPublisher
        let publisher2 = "abcdefghijklmnopqrstuvwxyz".asyncPublisher
        let publisher3 = "abcdefghijklmnopqrstuvwxyz".reversed().asyncPublisher

        let counter = Counter()
        let m1 = await select(publisher1, publisher2, publisher3)
            .sink { result in
                switch result {
                    case .value:
                        counter.increment()
                        return
                    case let .completion(.failure(error)):
                        XCTFail("Got an error? \(error)")
                        throw Publishers.Error.done
                    case .completion(.finished):
                        let count = counter.count
                        XCTAssert(count == 66, "wrong number of values sent: \(count)")
                        do { try expectation.succeed() }
                        catch { XCTFail("Failed to complete with error: \(error)") }
                        throw Publishers.Error.done
                }
            }

        _ = await m1.result
        _ = await expectation.result
    }

    func testInlineSelect() async throws {
        let expectation = AsyncPromise<Void>()

        let fseq1 = (101 ... 150).asyncPublisher
        let fseq2 = (1 ... 100).asyncPublisher

        let fm1 = Selected(fseq1, fseq2)

        let counter = Counter()
        let c1 = await fm1
            .sink { value in
                switch value {
                    case .value(_):
                        counter.increment()
                        return
                    case let .completion(.failure(error)):
                        XCTFail("Should not have received failure: \(error)")
                        throw Publishers.Error.done
                    case .completion(.finished):
                        let count = counter.count
                        XCTAssert(count == 150, "wrong number of values sent: \(count)")
                        do { try expectation.succeed() }
                        catch { XCTFail("Failed to complete with error: \(error)") }
                        throw Publishers.Error.done
                }
            }

        _ = await c1.result
        _ = await expectation.result
    }
}
