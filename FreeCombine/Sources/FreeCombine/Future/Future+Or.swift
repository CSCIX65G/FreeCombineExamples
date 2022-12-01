//
//  Future+Or.swift
//
//
//  Created by Van Simmons on 9/10/22.
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
public struct Or<Left, Right> {
    enum Current {
        case nothing
        case complete(Either<Left, Right>)
        case errored(Swift.Error)
    }

    public enum Action {
        case left(Result<Left, Swift.Error>)
        case right(Result<Right, Swift.Error>)
    }

    public struct State {
        var leftCancellable: Cancellable<Void>?
        var rightCancellable: Cancellable<Void>?
        var current: Current = .nothing
    }

    static func initialize(
        left: Future<Left>,
        right: Future<Right>
    ) -> (Queue<Action>) async -> State {
        { channel in
            await .init(
                leftCancellable: channel.consume(future: left, using: Action.left),
                rightCancellable: channel.consume(future: right, using: Action.right)
            )
        }
    }

    static func reduce(
        _ state: inout State,
        _ action: Action
    ) async -> AsyncFolder<State, Action>.Effect {
        do {
            try Cancellables.checkCancellation()
            switch (action, state.current) {
                case let (.left(leftResult), .nothing):
                    try? state.rightCancellable?.cancel()
                    state.rightCancellable = .none
                    state.current = try .complete(.left(leftResult.get()))
                    return .completion(.finished)
                case let (.right(rightResult), .nothing):
                    try? state.leftCancellable?.cancel()
                    state.leftCancellable = .none
                    state.current = try .complete(.right(rightResult.get()))
                    return .completion(.finished)
                default:
                    fatalError("Illegal state")
            }
        } catch {
            state.current = .errored(error)
            return .completion(.finished)
        }
    }

    static func dispose(
        _ action: Action,
        _ completion: AsyncFolder<State, Action>.Completion
    ) async -> Void {

    }

    static func finalize(
        state: inout State,
        completion: AsyncFolder<State, Action>.Completion
    ) async -> Void {
        try? state.rightCancellable?.cancel()
        state.rightCancellable = .none
        try? state.leftCancellable?.cancel()
        state.leftCancellable = .none
    }

    static func extract(state: State) throws -> Either<Left, Right> {
        switch state.current {
            case .nothing:
                throw CancellationError()
            case let .complete(value):
                return value
            case let .errored(error):
                throw error
        }
    }

    static func folder(
        left: Future<Left>,
        right: Future<Right>
    ) -> AsyncFolder<State, Action> {
        .init(
            initializer: initialize(left: left, right: right),
            reducer: reduce,
            disposer: dispose,
            finalizer: finalize
        )
    }
}
