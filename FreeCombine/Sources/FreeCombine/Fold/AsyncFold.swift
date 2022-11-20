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

    func send(
        _ element: Action
    ) throws -> Void {
        try channel.tryYield(element)
    }

    func finish() {
        channel.finish()
    }

    func cancel() throws {
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
        folder: AsyncFolder<State, Action>
    ) async -> Self {
        var fold: Self!
        try! await withResumption(function: function, file: file, line: line) { startup in
            fold = .init(
                function: function,
                file: file,
                line: line,
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
        onStartup: Resumption<Void>? = .none,
        channel: Channel<Action>,
        folder: AsyncFolder<State, Action>
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
        onStartup: Resumption<Void>? = .none,
        channel: Channel<Action>,
        folder: AsyncFolder<State, Action>
    ) async throws -> State {
        var state = await folder.initialize(channel: channel)
        do {
            onStartup?.resume()
            for await action in channel.stream {
                try await folder.handle(
                    effect: folder.reduce(state: &state, action: action),
                    channel: channel,
                    state: &state,
                    action: action
                )
                guard !Cancellables.isCancelled else { throw CancellationError() }
                try await folder.emit(state: &state)
            }
            await folder.finalize(&state, .finished)
        } catch {
            await folder.dispose(channel: channel, error: error)
            await folder.finalize(state: &state, error: error)
        }
        try await folder.emit(state: &state)
        return state
    }
}
