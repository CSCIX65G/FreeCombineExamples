//
//  TestClock.swift
//  
//
//  Created by Van Simmons on 11/26/22.
//  Inspired the PointFree version of the same.
//  Differences:
//  1. Lock-free
//  2. No "megaYield"
//  3. No AsyncStream<Never>
//  4. No Foundation
//  4. Uses composability tools from FreeCombine
//
#if swift(>=5.7) && (canImport(RegexBuilder) || !os(macOS) && !targetEnvironment(macCatalyst))
import Foundation

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
public final class TestClock<Duration: DurationProtocol & Hashable>: Clock, @unchecked Sendable {
    public struct Instant: InstantProtocol {
        public var offset: Duration

        public init(offset: Duration = .zero) {
            self.offset = offset
        }

        public func advanced(by duration: Duration) -> Self {
            .init(offset: self.offset + duration)
        }

        public func duration(to other: Self) -> Duration {
            other.offset - self.offset
        }

        public static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.offset < rhs.offset
        }
    }

    public var minimumResolution: Duration = .zero
    public private(set) var now: Instant

    private let lock = NSRecursiveLock()
    private var suspensions:
    [(
        id: UUID,
        deadline: Instant,
        continuation: AsyncThrowingStream<Never, Error>.Continuation
    )] = []

    public init(now: Instant = .init()) {
        self.now = .init()
    }

    public func sleep(until deadline: Instant, tolerance: Duration? = nil) async throws {
        try Task.checkCancellation()
        let id = UUID()
        do {
            let stream: AsyncThrowingStream<Never, Error>? = self.lock.sync {
                guard deadline >= self.now
                else {
                    return nil
                }
                return AsyncThrowingStream<Never, Error> { continuation in
                    self.suspensions.append((id: id, deadline: deadline, continuation: continuation))
                }
            }
            guard let stream = stream
            else { return }
            for try await _ in stream {}
            try Task.checkCancellation()
        } catch is CancellationError {
            self.lock.sync { self.suspensions.removeAll(where: { $0.id == id }) }
            throw CancellationError()
        } catch {
            throw error
        }
    }
    public func checkSuspension() async throws {
        await Task.megaYield()
        guard self.lock.sync(operation: { self.suspensions.isEmpty })
        else { throw SuspensionError() }
    }

    public func advance(by duration: Duration = .zero) async {
        await self.advance(to: self.lock.sync(operation: { self.now.advanced(by: duration) }))
    }

    public func advance(to deadline: Instant) async {
        while self.lock.sync(operation: { self.now <= deadline }) {
            await Task.megaYield()
            let `return` = {
                self.lock.lock()
                self.suspensions.sort { $0.deadline < $1.deadline }

                guard
                    let next = self.suspensions.first,
                    deadline >= next.deadline
                else {
                    self.now = deadline
                    self.lock.unlock()
                    return true
                }

                self.now = next.deadline
                self.suspensions.removeFirst()
                self.lock.unlock()
                next.continuation.finish()
                return false
            }()

            if `return` {
                await Task.megaYield()
                return
            }
        }
        await Task.megaYield()
    }

    public func run(
        timeout duration: Swift.Duration = .milliseconds(500),
        file: StaticString = #file,
        line: UInt = #line
    ) async {
        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    try await Task.sleep(until: .now.advanced(by: duration), clock: .continuous)
                    for suspension in self.suspensions {
                        suspension.continuation.finish(throwing: CancellationError())
                    }
                    throw CancellationError()
                }
                group.addTask {
                    await Task.megaYield()
                    while let deadline = self.lock.sync(operation: { self.suspensions.first?.deadline }) {
                        try Task.checkCancellation()
                        await self.advance(by: self.lock.sync(operation: { self.now.duration(to: deadline) }))
                    }
                }
                try await group.next()
                group.cancelAll()
            }
        } catch {
            Assertion.assertionFailure(
                """
                Expected all sleeps to finish, but some are still suspending after \(duration).

                There are sleeps suspending. This could mean you are not advancing the test clock far \
                enough for your feature to execute its logic, or there could be a bug in your feature's \
                logic.

                You can also increase the timeout of 'run' to be greater than \(duration).
                """
            )
        }
    }
}

public struct SuspensionError: Error {}

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
extension TestClock where Duration == Swift.Duration {
    public convenience init() {
        self.init(now: .init())
    }
}
#endif

extension NSLock {
    @inlinable
    @discardableResult
    func sync<R>(operation: () -> R) -> R {
        self.lock()
        defer { self.unlock() }
        return operation()
    }
}

extension NSRecursiveLock {
    @inlinable
    @discardableResult
    func sync<R>(operation: () -> R) -> R {
        self.lock()
        defer { self.unlock() }
        return operation()
    }
}

extension Task where Success == Failure, Failure == Never {
    // NB: We would love if this was not necessary, but due to a lack of async testing tools in Swift
    //     we're not sure if there is an alternative. See this forum post for more information:
    //     https://forums.swift.org/t/reliably-testing-code-that-adopts-swift-concurrency/57304
    static func megaYield(count: Int = 10) async {
        for _ in 1...count {
            await Task<Void, Never>.detached(priority: .background) { await Task.yield() }.value
        }
    }
}
