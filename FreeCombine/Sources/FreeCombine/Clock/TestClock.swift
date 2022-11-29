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
  2. No "megaYield"
  3. No AsyncStream<Never>
  4. No Foundation, uses Atomics instead
  4. Uses Cancellable and Resumption from FreeCombine to avoid races
 */
#if swift(>=5.7)
import Atomics

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
public final class TestClock: Clock, @unchecked Sendable {
    public typealias Duration = Swift.Duration
    public struct Instant: InstantProtocol, Sendable, Equatable, Hashable {
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

    public struct Suspension: Identifiable, Sendable, Hashable, Equatable {
        let deadline: Instant
        let resumption: Resumption<Void>
        public var id: ObjectIdentifier { resumption.id }
        public func release() -> Void { resumption.resume() }
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
        case advanceBy(duration: Swift.Duration)
        case advanceTo(deadline: Instant)
        case sleepUntil(deadline: Instant, resumption: Resumption<Void>)
        case runToCompletion(resumption: Resumption<Void>)
    }

    public let minimumResolution: Duration = .zero
    private let atomicState: ManagedAtomic<State>
    private var cancellable: Cancellable<Void>! = .none
    private var channel: Queue<Action>! = .none

    public init(now: Instant = .init(), pendingSuspensions: [Suspension] = []) {
        let localChannel = Queue<Action>.init(buffering: .unbounded)
        let localAtomicState = ManagedAtomic<State>(.init(now: now, pendingSuspensions: pendingSuspensions))

        self.atomicState = localAtomicState
        self.channel = localChannel
        self.cancellable = .init {
            for await action in localChannel.stream {
                self.reduce(action)
            }
            self.state.pendingSuspensions.forEach {
                $0.resumption.resume(throwing: SuspensionError())
            }
        }
    }

    public convenience init() {
        self.init(now: .init())
    }

    var state: State {
        atomicState.load(ordering: .sequentiallyConsistent)
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
                ordering: .sequentiallyConsistent
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

    private func reduce(_ action: Action) {
        switch action {
            case let .sleepUntil(deadline: deadline, resumption: resumption):
                guard deadline > self.now, !Cancellables.isCancelled else {
                    resumption.resume()
                    return
                }
                addSuspension(.init(deadline: deadline, resumption: resumption))
            case let .advanceBy(duration: duration):
                advanceTo(deadline: state.now.advanced(by: duration)).forEach { $0.release() }
            case let .advanceTo(deadline: deadline):
                guard deadline > self.now else { return }
                advanceTo(deadline: deadline).forEach { $0.release() }
            case let .runToCompletion(resumption: resumption):
                let releasedSuspensions = removeAllSuspensions()
                guard !releasedSuspensions.isEmpty else {
                    resumption.resume()
                    return
                }
                let error = SuspensionError()
                releasedSuspensions.forEach { $0.resumption.resume(throwing: error) }
                resumption.resume(throwing: error)
        }
    }

    public func advance(by duration: Duration = .zero) throws -> Void {
        self.channel.continuation.yield(.advanceBy(duration: duration))
    }

    func advance(to deadline: Instant) -> Void {
        guard deadline >= self.now else { return }
        self.channel.continuation.yield(.advanceTo(deadline: deadline))
    }

    public func sleep(until deadline: Instant, tolerance: Duration? = nil) async throws {
        guard deadline > self.now else { return }
        try Cancellables.checkCancellation()
        _ = try await pause { resumption in
            self.channel.continuation.yield(.sleepUntil(deadline: deadline, resumption: resumption))
        }
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
