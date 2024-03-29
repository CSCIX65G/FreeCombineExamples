//
//  Publisher+Select.swift
//  
//
//  Created by Van Simmons on 11/3/22.
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
import Queue
import SendableAtomics

public struct Select<Left: Sendable, Right: Sendable>: Sendable {
    enum Current: Sendable {
        case nothing
        case hasLeft(Left, Resumption<Void>)
        case hasRight(Right, Resumption<Void>)
        case finished
        case errored(Swift.Error)
    }

    public struct State: Sendable {
        var leftCancellable: Cancellable<Void>?
        var rightCancellable: Cancellable<Void>?
        var current: Current = .nothing
        let downstream: @Sendable (Publisher<Either<Left, Right>>.Result) async throws -> Void

        mutating func cancelLeft() throws -> Void {
            guard let can = leftCancellable else { throw SelectCancellationFailureError() }
            leftCancellable = .none
            try can.cancel()
        }

        mutating func cancelRight() throws -> Void {
            guard let can = rightCancellable else { throw SelectCancellationFailureError() }
            rightCancellable = .none
            try can.cancel()
        }
    }

    public enum Action: Sendable {
        case left(Publisher<Left>.Result, Resumption<Void>)
        case right(Publisher<Right>.Result, Resumption<Void>)
    }

    @Sendable static func initialize(
        left: Publisher<Left>,
        right: Publisher<Right>,
        downstream: @Sendable @escaping (Publisher<Either<Left, Right>>.Result) async throws -> Void
    ) -> @Sendable (Queue<Action>) async -> State {
        { channel in
            await .init(
                leftCancellable:  channel.consume(publisher: left, using: { Action.left($0, $1) }),
                rightCancellable: channel.consume(publisher: right, using: { Action.right($0, $1) }),
                downstream: downstream
            )
        }
    }

    @Sendable static func reduceLeft(state: inout State, value: Left, resumption: Resumption<Void>) -> AsyncFolder<State, Action>.Effect {
        switch (state.current) {
            case .nothing:
                state.current = .hasLeft(value, resumption)
                return Task.isCancelled ? .completion(.failure(CancellationError())): .none
            case .finished, .errored, .hasLeft, .hasRight:
                fatalError("Invalid state")
        }
    }
    @Sendable static func reduceLeft(state: inout State, error: Swift.Error, resumption: Resumption<Void>) -> AsyncFolder<State, Action>.Effect {
        try! resumption.resume(throwing: error)
        switch (state.current) {
            case .nothing:
                state.current = .errored(error)
                return .completion(.failure(error))
            case .finished, .errored, .hasLeft, .hasRight:
                fatalError("Invalid state")
        }
    }

    @Sendable static func reduceLeft(state: inout State, resumption: Resumption<Void>) -> AsyncFolder<State, Action>.Effect {
        try! resumption.resume(throwing: Publishers.Error.done)
        switch (state.current) {
            case .nothing:
                try? state.leftCancellable?.cancel()
                state.leftCancellable = .none
                state.current = state.rightCancellable == nil ? .finished : .nothing
                return state.rightCancellable == nil ? .completion(.finished) : .none
            case .finished, .errored, .hasLeft, .hasRight:
                fatalError("Invalid state")
        }
    }
    @Sendable static func reduceRight(state: inout State, value: Right, resumption: Resumption<Void>) -> AsyncFolder<State, Action>.Effect {
        switch (state.current) {
            case .nothing:
                state.current = .hasRight(value, resumption)
                return Task.isCancelled ? .completion(.failure(CancellationError())) : .none
            case .finished, .errored, .hasRight, .hasLeft:
                fatalError("Invalid state")
        }
    }
    @Sendable static func reduceRight(state: inout State, error: Swift.Error, resumption: Resumption<Void>) -> AsyncFolder<State, Action>.Effect {
        try! resumption.resume(throwing: error)
        switch (state.current) {
            case .nothing:
                state.current = .errored(error)
                return .completion(.failure(error))
            case .finished, .errored, .hasRight, .hasLeft:
                fatalError("Invalid state")
        }
    }
    @Sendable static func reduceRight(state: inout State, resumption: Resumption<Void>) -> AsyncFolder<State, Action>.Effect {
        try! resumption.resume(throwing: Publishers.Error.done)
        switch (state.current) {
            case .nothing:
                try? state.rightCancellable?.cancel()
                state.rightCancellable = .none
                state.current = state.leftCancellable == nil ? .finished : .nothing
                return state.leftCancellable == nil ? .completion(.finished) : .none
            case .finished, .errored, .hasRight, .hasLeft:
                fatalError("Invalid state")
        }
    }

    @Sendable static func reduce(
        _ state: inout State,
        _ action: Action
    ) async -> AsyncFolder<State, Action>.Effect {
        switch (action) {
            case let (.left(.value(value), resumption)):
                return reduceLeft(state: &state, value: value, resumption: resumption)
            case let (.left(.completion(.failure(error)), resumption)):
                return reduceLeft(state: &state, error: error, resumption: resumption)
            case let (.left(.completion(.finished), resumption)):
                return reduceLeft(state: &state, resumption: resumption)
            case let (.right(.value(value), resumption)):
                return reduceRight(state: &state, value: value, resumption: resumption)
            case let (.right(.completion(.failure(error)), resumption)):
                return reduceRight(state: &state, error: error, resumption: resumption)
            case let (.right(.completion(.finished), resumption)):
                return reduceRight(state: &state, resumption: resumption)
        }
    }

    @Sendable static func valuePair(_ current: Select<Left, Right>.Current) -> (Either<Left, Right>, Resumption<Void>)? {
        switch current {
            case .nothing, .finished, .errored:
                return .none
            case let .hasLeft(value, resumption):
                return (.left(value), resumption)
            case let .hasRight(value, resumption):
                return (.right(value), resumption)
        }
    }

    @Sendable static func emit(
        _ state: inout State
    ) async throws -> Void {
        switch valuePair(state.current) {
            case let .some((value, resumption)):
                state.current = try await AsyncResult<Void, Swift.Error> {
                    try await state.downstream(.value(value))
                }
                .map {
                    try! resumption.resume()
                    return Select<Left, Right>.Current.nothing
                }
                .mapError {
                    try! resumption.resume(throwing: $0)
                    return $0
                }
                .get()
                if case .finished = state.current { throw FinishedError() }
            default:
                ()
        }
    }

    @Sendable static func dispose(
        _ action: Action,
        _ completion: AsyncFolder<State, Action>.Completion
    ) async {
        var resumption: Resumption<Void>!
        switch action {
            case let .left(_, lResumption): resumption = lResumption
            case let .right(_, rResumption): resumption = rResumption
        }
        switch completion {
            case .finished: try! resumption.resume(throwing: Publishers.Error.done)
            case let .failure(error): try! resumption.resume(throwing: error)
        }
    }

    @Sendable static func resumption(_ current: Select<Left, Right>.Current) -> Resumption<Void>? {
        switch current {
            case .nothing, .finished, .errored:
                return .none
            case let .hasLeft(_, resumption):
                return resumption
            case let .hasRight(_, resumption):
                return resumption
        }
    }

    @Sendable static func finalize(
        state: inout State,
        completion: AsyncFolder<State, Action>.Completion
    ) async {
        try? state.cancelRight()
        try? state.cancelLeft()
        let resumption = resumption(state.current)
        switch completion {
            case .finished:
                _ = try? await state.downstream(.completion(.finished))
                try? resumption?.resume(throwing: Publishers.Error.done)
            case let .failure(error):
                _ = try? await state.downstream(.completion(.failure(error)))
                try? resumption?.resume(throwing: error)
        }
        state.current = .nothing
    }

    static func folder(
        left: Publisher<Left>,
        right: Publisher<Right>,
        downstream: @Sendable @escaping (Publisher<Either<Left, Right>>.Result) async throws -> Void
    ) -> AsyncFolder<State, Action> {
        .init(
            initializer: initialize(left: left, right: right, downstream: downstream),
            reducer: reduce,
            emitter: emit,
            disposer: dispose,
            finalizer: finalize
        )
    }
}
