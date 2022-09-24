//
//  AsyncFold.swift
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
 # Async let Problems

 1. Cannot be cancelled

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

 # AsyncFold Action Requirements:

 1. Sendable funcs
 2. routable
 3. value types
 4. some actions are blocking, these need special handling (think DO oneway keyword)

 From: [SE-304 Structured Concurrency](https://github.com/apple/swift-evolution/blob/main/proposals/0304-structured-concurrency.md#structured-concurrency-1)
 > Systems that rely on queues are often susceptible to queue-flooding, where the queue accepts more work than it can actually handle. This is typically solved by introducing "back-pressure": a queue stops accepting new work, and the systems that are trying to enqueue work there respond by themselves stopping accepting new work. Actor systems often subvert this because it is difficult at the scheduler level to refuse to add work to an actor's queue, since doing so can permanently destabilize the system by leaking resources or otherwise preventing operations from completing. Structured concurrency offers a limited, cooperative solution by allowing systems to communicate up the task hierarchy that they are coming under distress, potentially allowing parent tasks to stop or slow the creation of presumably-similar new work.

 FreeCombines addresses this differently by allowing backpressure and explicit disposal of queued items.

 [Child Tasks](https://github.com/apple/swift-evolution/blob/main/proposals/0304-structured-concurrency.md#child-tasks)
 > An asynchronous function can create a child task. Child tasks inherit some of the structure of their parent task, including its priority, but can run concurrently with it. However, this concurrency is bounded: a function that creates a child task must wait for it to end before returning. This structure means that functions can locally reason about all the work currently being done for the current task, anticipate the effects of cancelling the current task, and so on. It also makes creating the child task substantially more efficient.

 [Task Groups and Child Tasks](https://github.com/apple/swift-evolution/blob/main/proposals/0304-structured-concurrency.md#task-groups-and-child-tasks)
 
 > By contrast with future-based task APIs, there is no way in which a reference to the child task can escape the scope in which the child task is created. This ensures that the structure of structured concurrency is maintained.

 This definition of structured concurrency is extremely limiting and precludes the monadic use of Task.
 */
public final class AsyncFold<State, Action: Sendable> {
    private let function: StaticString
    private let file: StaticString
    private let line: UInt

    let channel: Channel<Action>

    public let cancellable: Cancellable<State>

    init(
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

    @Sendable func cancel() throws {
        try cancellable.cancel()
    }
}

extension AsyncFold {
    var future: Future<State> {
        .init { resumption, downstream in
            .init { await downstream(self.cancellable.result) }
        }
    }
}

extension AsyncFold {
    static func fold(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        channel: Channel<Action>,
        folder: Folder<State, Action>
    ) async -> Self {
        var fold: Self!
        try! await withResumption(function: function, file: file, line: line) { startup in
            fold = .init(
                onStartup: startup,
                channel: channel,
                folder: folder
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
        folder: Folder<State, Action>
    ) {
        self.init(
            function: function,
            file: file,
            line: line,
            channel: channel,
            cancellable: .init(function: function, file: file, line: line) {
                try await withTaskCancellationHandler(
                    operation: {
                        try await Self.runloop(onStartup: onStartup, channel: channel, folder: folder)
                    },
                    onCancel: channel.finish
                )
            }
        )
    }

    private static func runloop(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        onStartup: Resumption<Void>,
        channel: Channel<Action>,
        folder: Folder<State, Action>
    ) async throws -> State {
        var state = await folder.initialize(channel: channel)
        do {
            onStartup.resume()
            for await action in channel.stream {
                try await folder.reduce(state: &state, action: action)
            }
            await folder.finalize(&state, .finished)
        } catch {
            await folder.dispose(channel: channel, error: error)
            try await folder.finalize(state: &state, error: error)
        }
        return state
    }
}
