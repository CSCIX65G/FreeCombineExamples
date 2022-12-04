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
import Core

public struct FinishedError: Swift.Error, Sendable, Equatable { }

public struct AsyncFolder<State, Action> {
    public enum Effect {
        case none  // Multiply by 1
        case completion(Completion) // Multiply by 0
        case publish((Queue<Action>) -> Void)
    }
    
    public typealias Completion = Publishers.Completion
    
    let initializer: (Queue<Action>) async -> State
    let reducer: (inout State, Action) async throws -> Effect
    let emitter: (inout State) async throws -> Void
    let disposer: (Action, Completion) async -> Void
    let finalizer: (inout State, Completion) async -> Void
    
    public init(
        initializer: @escaping (Queue<Action>) async -> State,
        reducer: @escaping (inout State, Action) async throws -> Effect,
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
    
    public func callAsFunction(_ channel: Queue<Action>) async -> State {
        await initializer(channel)
    }
    
    public func callAsFunction(_ state: inout State, _ action: Action) async throws -> Effect {
        try await reducer(&state, action)
    }
    
    public func callAsFunction(_ action: Action, _ completion: Completion) async -> Void {
        await disposer(action, completion)
    }
    
    public func callAsFunction(_ state: inout State, _ completion: Completion) async -> Void {
        await finalizer(&state, completion)
    }
    
    public func callAsFunction(_ state: inout State) async throws -> Void {
        try await emitter(&state)
    }
}

extension AsyncFolder {
    func initialize(channel: Queue<Action>) async -> State {
        await self(channel)
    }

    func reduce(state: inout State, action: Action) async throws -> Effect {
        try await reducer(&state, action)
    }

    func handle(
        effect: Effect,
        channel: Queue<Action>,
        state: inout State,
        action: Action
    ) async throws -> Void {
        switch effect {
            case .none:
                ()
            case .completion(let .failure(error)):
                throw error
            case .completion(.finished):
                throw FinishedError()
            case .publish:
                ()
        }
    }

    func emit(
        state: inout State
    ) async throws -> Void {
        try await emitter(&state)
    }

    func dispose(
        channel: Queue<Action>,
        error: Swift.Error
    ) async -> Void {
        channel.finish()
        for await action in channel.stream {
            switch error {
                case is FinishedError:
                    await self(action, .finished); continue
                case is CancellationError:
                    await self(action, .failure(error)); continue
                default:
                    await self(action, .failure(error)); continue
            }
        }
    }

    func finalize(
        state: inout State,
        error: Swift.Error
    ) async -> Void {
        switch error {
            case is FinishedError:
                await self(&state, .finished)
            default:
                await self(&state, .failure(error))
        }
    }

    func finalize(_ state: inout State, _ completion: Completion) async -> Void {
        await self(&state, completion)
    }
}
