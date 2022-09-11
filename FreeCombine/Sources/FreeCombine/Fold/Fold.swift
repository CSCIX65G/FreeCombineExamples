//
//  StateTask.swift
//
//  Created by Van Simmons on 2/17/22.
//
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

/*:
 # Actor Problems

 1. no oneway funcs (i.e. they can’t be called from synchronous code)
 2. can’t selectively block callers in order (i.e. passing a continuation to an actor requires spawning a task which gives up ordering guarantees)
 3. can’t block calling tasks on internal state (can only block with async call to another task)
 4. have no concept of cancellation (cannot perform orderly shutdown with outstanding requests in flight)
 5. they execute on global actor queues (generally not needed or desirable to go off-Task for these things)
 6. No way to allow possible failure to enqueue on an overburdened actor, all requests enter an unbounded queue

 # Actor Solutions: StateTask - a swift implementation of the Haskell ST monad

 From: [Lazy Functional State Threads](https://www.microsoft.com/en-us/research/wp-content/uploads/1994/06/lazy-functional-state-threads.pdf)

 1. LOCK FREE CHANNELS
 2. Haskell translation: ∀s in Rank-N types becomes a Task
 3. Use explicit queues to process events

 # StateTask Action Requirements:

 1. Sendable funcs
 2. routable
 3. value types
 4. some actions are blocking, these need special handling (think DO oneway keyword)

 From: [SE-304 Structured Concurrency](https://github.com/apple/swift-evolution/blob/main/proposals/0304-structured-concurrency.md#structured-concurrency-1)
 > Systems that rely on queues are often susceptible to queue-flooding, where the queue accepts more work than it can actually handle. This is typically solved by introducing "back-pressure": a queue stops accepting new work, and the systems that are trying to enqueue work there respond by themselves stopping accepting new work. Actor systems often subvert this because it is difficult at the scheduler level to refuse to add work to an actor's queue, since doing so can permanently destabilize the system by leaking resources or otherwise preventing operations from completing. Structured concurrency offers a limited, cooperative solution by allowing systems to communicate up the task hierarchy that they are coming under distress, potentially allowing parent tasks to stop or slow the creation of presumably-similar new work.

 FreeCombines addresses this differently by allowing backpressure and explicit disposal of queued items.
 */
public final class Fold<State, Action: Sendable> {
    let channel: Channel<Action>
    let cancellable: Cancellable<State>

    public let function: StaticString
    public let file: StaticString
    public let line: UInt

    fileprivate init(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        channel: Channel<Action>,
        cancellable: Cancellable<State>
    ) {
        self.function = function
        self.file = file
        self.line = line
        self.channel = channel
        self.cancellable = cancellable
    }

    deinit {
        guard canDeinit else {
            assertionFailure(
                "ABORTING DUE TO LEAKED \(type(of: Self.self))  CREATED in \(function) @ \(file): \(line)"
            )
            cancellable.cancel()
            return
        }
    }

    public var isCancelled: Bool { @Sendable get { cancellable.isCancelled } }
    public var isCompleting: Bool { @Sendable get { cancellable.isCompleting } }
    public var canDeinit: Bool { @Sendable get { cancellable.isCompleting || cancellable.isCancelled } }

    public var value: State {
        get async throws { try await cancellable.value }
    }

    var result: Result<State, Swift.Error> {
        get async { await cancellable.result }
    }

    @Sendable func send(
        _ element: Action
    ) -> AsyncStream<Action>.Continuation.YieldResult {
        channel.yield(element)
    }

    @Sendable func finish() {
        channel.finish()
    }

    @Sendable func cancel() {
        cancellable.cancel()
    }
}

extension Fold {
    var future: Future<State> {
        .init { resumption, downstream in
            .init {
                await downstream(self.cancellable.result)
            }
        }
    }
}

extension Fold {
    private enum Error: Swift.Error {
        case completed
        case internalError
        case cancelled
    }

    static func fold(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        channel: Channel<Action>,
        reducer: Reducer<State, Action>
    ) async -> Self {
        var fold: Self!
        try! await withResumption(function: function, file: file, line: line) { startup in
            fold = .init(
                onStartup: startup,
                channel: channel,
                reducer: reducer
            )
        }
        return fold
    }

    public convenience init(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        onStartup: Resumption<Void>,
        channel: Channel<Action>,
        reducer: Reducer<State, Action>
    ) {
        self.init(
            function: function,
            file: file,
            line: line,
            channel: channel,
            cancellable: .init(function: function, file: file, line: line) {
                try await withTaskCancellationHandler(
                    operation: {
                        var state = await reducer.initialize(channel: channel)
                        onStartup.resume()
                        do {
                            try await withTaskCancellationHandler(
                                operation: {
                                    for await action in channel.stream {
                                        try await reducer.reduce(
                                            state: &state,
                                            action: action,
                                            channel: channel
                                        )
                                    }
                                    await reducer.finalize(&state, .finished)
                                },
                                onCancel: channel.finish
                            )
                        } catch {
                            await reducer.dispose(channel: channel, error: error)
                            try await reducer.finalize(state: &state, error: error)
                        }
                        return state

                    },
                    onCancel: {
                        channel.finish()
                    }
                )
            }
        )
    }
}
