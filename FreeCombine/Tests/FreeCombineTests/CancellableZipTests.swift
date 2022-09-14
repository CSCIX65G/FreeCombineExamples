import XCTest

@testable import FreeCombine

final class CancellableZipTests: XCTestCase {
    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testSimpleZip() async throws {
        let leftPromise: Promise<Int> = await .init()
        let rightPromise: Promise<String> = await .init()

        let zipped = zip(leftPromise.cancellable, rightPromise.cancellable)

        let c: Cancellable<Void> = .init {
            let zValue = await zipped.result
            switch zValue {
                case let .success(pair):
                    XCTAssert(pair.0 == 13, "Wrong left hand side")
                    XCTAssert(pair.1 == "Hello, world!", "Wrong right hand side")
                case let .failure(error):
                    XCTFail("received: \(error)")
            }
        }

        try leftPromise.succeed(13)
        try rightPromise.succeed("Hello, world!")
        _ = await c.result
    }

    func testSimpleZipFailure() async throws {
        enum Error: Swift.Error, Equatable {
            case left
            case right
        }
        let leftPromise: Promise<Int> = await .init()
        let rightPromise: Promise<String> = await .init()

        let zipped = zip(leftPromise.cancellable, rightPromise.cancellable)

        let c: Cancellable<Void> = .init {
            let zValue = await zipped.result
            switch zValue {
                case .success:
                    XCTFail("Should not have received value")
                case let .failure(error):
                    guard let error = error as? Error, error == .right else {
                        XCTFail("received incorrect error: \(error)")
                        return
                    }
            }
        }

        try rightPromise.fail(Error.right)
        _ = await c.result
        try leftPromise.fail(Error.left)
    }

    func testSimpleZipCancellation() async throws {
        enum Error: Swift.Error, Equatable {
            case left
            case right
        }
        let leftPromise: Promise<Int> = await .init()
        let rightPromise: Promise<String> = await .init()

        let zipped = zip(leftPromise.cancellable, rightPromise.cancellable)

        let c: Cancellable<Void> = .init {
            let zValue = await zipped.result
            switch zValue {
                case .success:
                    XCTFail("Should not have received value")
                case let .failure(error):
                    guard error is Cancellables.Error else {
                        XCTFail("received incorrect error: \(error)")
                        return
                    }
            }
        }

        try zipped.cancel()
        _ = await zipped.result
        _ = await c.result
        try? leftPromise.cancel()
        try? rightPromise.cancel()
    }

}
