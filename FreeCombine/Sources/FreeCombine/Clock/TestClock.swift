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
#if swift(>=5.7)
import Atomics
import Foundation

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
public final class TestClock: Clock, @unchecked Sendable {
    public typealias Duration = Swift.Duration
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

    public struct Suspension: Identifiable {
        let deadline: Instant
        let promise: Promise<Void>
        public var id: ObjectIdentifier { promise.id }
    }

    final class State: AtomicReference, Identifiable {
        private(set) var id: ObjectIdentifier! = .none
        let now: Instant
        let suspensions: [Suspension]
        init(now: Instant, suspensions: [Suspension] = []) {
            self.now = now
            self.suspensions = suspensions
            self.id = .init(self)
        }
    }

    public let minimumResolution: Duration = .zero
    private let atomicState: ManagedAtomic<State>

    public var now: Instant {
        atomicState.load(ordering: .sequentiallyConsistent).now
    }

    var state: State {
        atomicState.load(ordering: .sequentiallyConsistent)
    }

    private func addSuspension(_ suspension: Suspension) -> Void {
        var localState = state
        while true {
            let newState = State(
                now: localState.now,
                suspensions: localState.suspensions + [suspension]
            )
            let (success, newLocalState) = atomicState.compareExchange(
                expected: localState,
                desired: newState,
                ordering: .sequentiallyConsistent
            )
            if success { break }
            localState = newLocalState
        }
    }

    private func removeSuspensions(_ id: ObjectIdentifier) -> Void {
        var localState = state
        while true {
            let newState = State(
                now: localState.now,
                suspensions: localState.suspensions.filter { $0.id != id }
            )
            let (success, newLocalState) = atomicState.compareExchange(
                expected: localState,
                desired: newState,
                ordering: .sequentiallyConsistent
            )
            if success { break }
            localState = newLocalState
        }
    }

    private func removeAllSuspensions() -> [Suspension] {
        var localState = state
        while true {
            let newState = State(
                now: localState.now,
                suspensions: []
            )
            let (success, newLocalState) = atomicState.compareExchange(
                expected: localState,
                desired: newState,
                ordering: .sequentiallyConsistent
            )
            if success { return localState.suspensions }
            localState = newLocalState
        }
    }

    public init(now: Instant = .init(), suspensions: [Suspension] = []) {
        self.atomicState = .init(.init(now: now, suspensions: suspensions))
    }

    public func sleep(until deadline: Instant, tolerance: Duration? = nil) async throws {
        guard deadline >= self.now else { return }
        try Cancellables.checkCancellation()
        let promise = await Promise<Void>()
        do {
            addSuspension(.init(deadline: deadline, promise: promise))
            _ = await promise.result
            try Cancellables.checkCancellation()
        } catch is CancellationError {
            removeSuspensions(promise.id)
            throw CancellationError()
        } catch {
            throw error
        }
    }

    public func checkSuspension() async throws {
        await Task.megaYield()
        guard state.suspensions.isEmpty else { throw SuspensionError() }
    }

    public func advance(by duration: Duration = .zero) async {
        while true {
            do { try await tryAdvance(to: state.now.advanced(by: duration)); return }
            catch { }
        }
    }
    public func advance(to deadline: Instant) async throws {
        while true {
            do { try await tryAdvance(to: deadline); return }
            catch { }
        }
    }

    private func tryAdvance(to deadline: Instant) async throws {
        guard deadline >= self.now else { return }
        await Task.megaYield()
        let localState = state
        let sortedSuspensions = localState.suspensions.sorted { $0.deadline < $1.deadline }
        let newSuspensions = sortedSuspensions.filter { $0.deadline > deadline }
        let suspensionsToFulfill = sortedSuspensions.filter { $0.deadline <= deadline }

        let newState = State(
            now: deadline,
            suspensions: newSuspensions
        )
        let (success, _) = atomicState.compareExchange(
            expected: localState,
            desired: newState,
            ordering: .sequentiallyConsistent
        )
        guard success else { throw SuspensionError() }
        suspensionsToFulfill.forEach { try? $0.promise.succeed() }
        await Task.megaYield()
    }

    public func runToCompletion(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line
    ) async {
        let suspensions = removeAllSuspensions()
        guard !suspensions.isEmpty else { return }
        let error = SuspensionError()
        suspensions.forEach { try? $0.promise.fail(error) }
        Assertion.assertionFailure(
            """
            Expected all sleeps to finish, but some are still suspended.
            
            This could mean you are not advancing the test clock far \
            enough for your feature to execute its logic, or there could be a bug in your feature's \
            timing.
            """
        )
    }
}

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
extension TestClock {
    public convenience init() {
        self.init(now: .init())
    }
}
#endif

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
