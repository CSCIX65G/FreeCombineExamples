//
//  TestClock.swift
//  
//
//  Created by Van Simmons on 11/26/22.
//  Copyright 2022, ComputeCycles, LLC
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//
/*:  Inspired the PointFree version of the same.
  Differences:
  1. Lock-free
  2. Corollary: No import Foundation, uses Atomics instead
  3. No "megaYield"
  4. Uses Resumption<Void> instead of AsyncStream<Never>
  5. Uses Cancellable and Resumption from FreeCombine to avoid races
  6. Optionally allows each suspension to signal that the clock can now tick again
  7. Gathers performance information at advances
  8. Follows real clock behavior of not allowing sleeping in cancelled tasks
 */
#if swift(>=5.7)
import Atomics
import Core
import Channel
import Queue
import Future

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
extension [DiscreteClock.Suspension] {
    func release() async -> Void {
        forEach {
            $0.release()
        }
    }

    @discardableResult
    func fail(with error: Error) async -> Self {
        forEach {
            try! $0.resumption.resume(throwing: error)
        }
        return self
    }
}

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
public final class DiscreteClock: Clock, @unchecked Sendable {
    public typealias Duration = Swift.Duration
    public struct Instant: InstantProtocol, Sendable, Equatable, Hashable {
        public private(set) var offset: Duration

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

    public struct Suspension: Identifiable, Sendable, Hashable, Equatable {
        let deadline: Instant
        let resumption: Resumption<Void>

        public var id: ObjectIdentifier {
            ObjectIdentifier(resumption)
        }
        public func release() -> Void {
            try! resumption.resume()
        }
        public func fail(with error: Error) -> Void {
            try! resumption.resume(throwing: error)
        }
    }

    final class State: AtomicReference, Sendable  {
        let now: Instant
        let pendingSuspensions: [Suspension]
        init(now: Instant, pendingSuspensions: [Suspension] = []) {
            self.now = now
            self.pendingSuspensions = pendingSuspensions
        }
    }

    enum Action {
        case advanceBy(duration: Swift.Duration, resumption: Resumption<Instant>)
        case advanceTo(deadline: Instant, resumption: Resumption<Void>)
        case sleepUntil(deadline: Instant, resumption: Resumption<Void>)
        case cancelSleep(resumption: Resumption<Void>)
        case runToCompletion(resumption: Resumption<Void>)
    }

    public let minimumResolution: Duration = .zero

    private let atomicState: ManagedAtomic<State>
    private let channel: Queue<Action>
    private var connector: Cancellable<Void>! = .none

    public init(now: Instant = .init(), pendingSuspensions: [Suspension] = []) {
        let localChannel = Queue<Action>.init(buffering: .unbounded)
        let localAtomicState = ManagedAtomic<State>(.init(now: now, pendingSuspensions: pendingSuspensions))

        self.atomicState = localAtomicState
        self.channel = localChannel
        self.connector = .init {
            for await action in localChannel.stream {
                await self.reduce(action)
            }
            self.state.pendingSuspensions.forEach {
                try! $0.resumption.resume(throwing: SuspensionError())
            }
        }
    }

    public convenience init() {
        self.init(now: .init())
    }

    var state: State {
        atomicState.load(ordering: .relaxed)
    }

    public var now: Instant {
        state.now
    }

    @discardableResult
    private func updateState(using next: (State) -> (State, [Suspension])) -> [Suspension] {
        var localState = state
        var releasableSuspensions = [Suspension]()
        while true {
            let (newState, newReleasedSuspensions) = next(localState)
            let (success, newLocalState) = atomicState.compareExchange(
                expected: localState,
                desired: newState,
                ordering: .relaxed
            )
            if success {
                releasableSuspensions = newReleasedSuspensions
                break
            }
            localState = newLocalState
        }
        return releasableSuspensions
    }

    private func addSuspension(_ suspension: Suspension) -> Void {
        updateState { state in
            return (.init(now: state.now, pendingSuspensions: state.pendingSuspensions + [suspension]), [])
        }
    }

    private func removeAllSuspensions() -> [Suspension] {
        updateState { state in
            let newReleased = state.pendingSuspensions
            return (.init(now: state.now, pendingSuspensions: []), newReleased)
        }
    }

    private func advanceTo(deadline: Instant) -> [Suspension] {
        updateState { state in
            let sortedSuspensions = state.pendingSuspensions.sorted { $0.deadline < $1.deadline }
            let newPending = sortedSuspensions.filter { $0.deadline > deadline }
            let newReleased = sortedSuspensions.filter { $0.deadline <= deadline }
            return (.init(now: deadline, pendingSuspensions: newPending), newReleased)
        }
    }

    private func cancel(resumption: Resumption<Void>) -> [Suspension] {
        updateState { state in
            let sortedSuspensions = state.pendingSuspensions.sorted { $0.deadline < $1.deadline }
            let newPending = sortedSuspensions.filter { $0.resumption != resumption }
            let newReleased = sortedSuspensions.filter { $0.resumption == resumption }
            return (.init(now: now, pendingSuspensions: newPending), newReleased)
        }
    }

    private func reduce(_ action: Action) async {
        switch action {
            case let .sleepUntil(deadline: deadline, resumption: resumption):
                guard deadline > self.now, !Task.isCancelled else {
                    try! resumption.resume()
                    return
                }
                addSuspension(.init(deadline: deadline, resumption: resumption))
            case let .advanceBy(duration: duration, resumption: resumption):
                await advanceTo(deadline: state.now.advanced(by: duration)).release()
                try! resumption.resume(returning: state.now)
            case let .advanceTo(deadline: deadline, resumption: resumption):
                guard deadline > self.now else { return }
                await advanceTo(deadline: deadline).release()
                try! resumption.resume()
            case let .cancelSleep(resumption: resumption):
                await cancel(resumption: resumption).fail(with: CancellationError())
            case let .runToCompletion(resumption: resumption):
                guard await !removeAllSuspensions().fail(with: SuspensionError()).isEmpty else {
                    try! resumption.resume()
                    return
                }
                try! resumption.resume(throwing: SuspensionError())
        }
    }

    @discardableResult
    public func advance(by duration: Duration = .zero) async throws -> Instant {
        try await pause { resumption in
            self.channel.continuation.yield(.advanceBy(duration: duration, resumption: resumption))
        }
    }

    func advance(to deadline: Instant) async throws -> Void {
        guard deadline >= self.now else { return }
        try await pause { resumption in
            self.channel.continuation.yield(.advanceTo(deadline: deadline, resumption: resumption))
        }
    }

    public func sleep(for duration: Duration, tolerance: Duration? = nil) async throws -> Void {
        try await sleep(until: now.advanced(by: duration), tolerance: tolerance)
    }

    public func sleep(until deadline: Instant, tolerance: Duration? = nil) async throws -> Void {
        guard deadline > self.now else { return }
        try Task.checkCancellation()
        let promise = AsyncPromise<Resumption<Void>>()
        try await withTaskCancellationHandler(
            operation: {
                try await pause { resumption in
                    self.channel.continuation.yield(.sleepUntil(deadline: deadline, resumption: resumption))
                    do { try promise.succeed(resumption) }
                    catch { fatalError("Promise should never fail here") }
                }
            },
            onCancel: {
//                try? Uncancellable<Void> {
//                    guard case let .success(resumption) = await promise.result else {
//                        return
//                    }
//                    self.channel.continuation.yield(.cancelSleep(resumption: resumption))
//                }.release()
            }
        )
        _ = await promise.result
    }

    public func runToCompletion(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line
    ) async {
        do {
            _ = try await pause { resumption in
                self.channel.continuation.yield(.runToCompletion(resumption: resumption))
            }
        } catch {
            Assertion.assertionFailure(
                """
                Expected all sleeps to finish, but some are still suspended.  Invoked from:

                \(function): \(file)@\(line)

                This could mean you are not advancing the test clock far \
                enough for your feature to execute its logic, or there could be a bug in your feature's \
                timing.
                """
            )
        }
    }
}
#endif
