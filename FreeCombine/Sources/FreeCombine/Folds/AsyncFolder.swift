//
//  AsyncFolder.swift
//
//
//  Created by Van Simmons on 5/25/22.
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
public enum AsyncFolders {
    public enum Completion {
        case exited
        case failure(Swift.Error)
        case finished
    }

    public enum Error: Swift.Error {
        case cancelled
        case completed
        case finished
    }
}

public struct AsyncFolder<State, Action> {
    public typealias Completion = AsyncFolders.Completion
    public typealias Error = AsyncFolders.Error
    
    let initializer: (Channel<Action>) async -> State
    let reducer: (inout State, Action) async throws -> [Effect]
    let emitter: (inout State) async throws -> Void
    let disposer: (Action, Completion) async -> Void
    let finalizer: (inout State, Completion) async -> Void

    public init(
        initializer: @escaping (Channel<Action>) async -> State,
        reducer: @escaping (inout State, Action) async throws -> [Effect],
        emitter: @escaping (inout State) async throws -> Void = { _ in },
        disposer: @escaping (Action, Completion) async -> Void = { _, _ in },
        finalizer: @escaping (inout State, Completion) async -> Void = { _, _ in }
    ) {
        self.initializer = initializer
        self.reducer = reducer
        self.emitter = emitter
        self.disposer = disposer
        self.finalizer = finalizer
    }

    public func callAsFunction(_ channel: Channel<Action>) async -> State {
        await initializer(channel)
    }

    public func callAsFunction(_ state: inout State, _ action: Action) async throws -> [Effect] {
        try await reducer(&state, action)
    }

    public func callAsFunction(_ action: Action, _ completion: Completion) async -> Void {
        await disposer(action, completion)
    }

    public func callAsFunction(_ state: inout State, _ completion: Completion) async -> Void {
        await finalizer(&state, completion)
    }
}

extension AsyncFolder {
    func initialize(channel: Channel<Action>) async -> State {
        await self(channel)
    }

    func reduce(state: inout State, action: Action) async throws -> [Effect] {
        try await reducer(&state, action)
    }

    func handle(
        effects: [Effect],
        channel: Channel<Action>,
        state: inout State,
        action: Action
    ) async throws -> Void {
        for effect in effects {
            switch effect {
                case .none: ()
                case .completion(.exited): throw Error.completed
                case .completion(let .failure(error)): throw error
                case .completion(.finished): throw Error.finished
                case .emit:
                    try await emitter(&state)
                case .publish: ()
            }
        }
    }

    func dispose(
        channel: Channel<Action>,
        error: Swift.Error
    ) async -> Void {
        channel.finish()
        for await action in channel.stream {
            switch error {
                case Error.completed:
                    await self(action, .finished); continue
                case Error.cancelled:
                    await self(action, .failure(Error.cancelled)); continue
                default:
                    await self(action, .failure(error)); continue
            }
        }
    }

    func finalize(
        state: inout State,
        error: Swift.Error
    ) async throws -> Void {
        guard let completion = error as? Error else {
            await self(&state, .failure(error))
            throw error
        }
        switch completion {
            case .cancelled:
                await self(&state, .failure(Error.cancelled))
                throw completion
            case .finished:
                await self(&state, .finished)
            case .completed:
                await self(&state, .exited)
        }
    }

    func finalize(_ state: inout State, _ completion: Completion) async -> Void {
        await self(&state, completion)
    }
}
