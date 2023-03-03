//
//  Publisher+Zip.swift
//
//
//  Created by Van Simmons on 9/6/22.
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

public struct Zip<Left: Sendable, Right: Sendable> {
    enum Current: Sendable {
        case nothing
        case hasLeft(Left, Resumption<Void>)
        case hasRight(Right, Resumption<Void>)
        case hasBoth(Left, Resumption<Void>, Right, Resumption<Void>)
        case finished
        case errored(Swift.Error)
    }

    public struct State : Sendable {
        var leftCancellable: Cancellable<Void>?
        var rightCancellable: Cancellable<Void>?
        var current: Current = .nothing
        let downstream: @Sendable (Publisher<(Left, Right)>.Result) async throws -> Void

        mutating func cancelLeft() throws -> Void {
            guard let can = leftCancellable else { throw ZipCancellationFailureError() }
            leftCancellable = .none
            try can.cancel()
        }

        mutating func cancelRight() throws -> Void {
            guard let can = rightCancellable else { throw ZipCancellationFailureError() }
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
        downstream: @Sendable @escaping (Publisher<(Left, Right)>.Result) async throws -> Void
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
                return Task.isCancelled ? .completion(.failure(CancellationError())) : .none
            case let .hasRight(rightValue, rightResumption):
                state.current = .hasBoth(value, resumption, rightValue, rightResumption)
                return Task.isCancelled ? .completion(.failure(CancellationError())): .none
            case .finished, .errored, .hasLeft, .hasBoth:
                fatalError("Invalid state")
        }
    }

    @Sendable static func reduceLeft(state: inout State, error: Swift.Error, resumption: Resumption<Void>) -> AsyncFolder<State, Action>.Effect {
        try! resumption.resume(throwing: error)
        switch (state.current) {
            case .nothing:
                state.current = .errored(error)
                return .completion(.failure(error))
            case let .hasRight(_, rightResumption):
                try! rightResumption.resume(throwing: error)
                state.current = .errored(error)
                return .completion(.failure(error))
            case .finished, .errored, .hasLeft, .hasBoth:
                fatalError("Invalid state")
        }
    }

    @Sendable static func reduceLeft(state: inout State, resumption: Resumption<Void>) -> AsyncFolder<State, Action>.Effect {
        try! resumption.resume(throwing: Publishers.Error.done)
        switch (state.current) {
            case .nothing:
                state.current = .finished
                return .completion(.finished)
            case let .hasRight(_, rightResumption):
                try! rightResumption.resume(throwing: Publishers.Error.done)
                state.current = .finished
                return .completion(.finished)
            case .finished, .errored, .hasLeft, .hasBoth:
                fatalError("Invalid state")
        }
    }

    @Sendable static func reduceRight(state: inout State, value: Right, resumption: Resumption<Void>) -> AsyncFolder<State, Action>.Effect {
        switch (state.current) {
            case .nothing:
                state.current = .hasRight(value, resumption)
                return Task.isCancelled ? .completion(.failure(CancellationError())) : .none
            case let .hasLeft(leftValue, leftResumption):
                state.current = .hasBoth(leftValue, leftResumption, value, resumption)
                return Task.isCancelled ? .completion(.failure(CancellationError())) : .none
            case .finished, .errored, .hasRight, .hasBoth:
                fatalError("Invalid state")
        }
    }

    @Sendable static func reduceRight(state: inout State, error: Swift.Error, resumption: Resumption<Void>) -> AsyncFolder<State, Action>.Effect {
        try! resumption.resume(throwing: error)
        switch (state.current) {
            case .nothing:
                state.current = .errored(error)
                return .completion(.failure(error))
            case let .hasLeft(_, leftResumption):
                try! leftResumption.resume(throwing: error)
                state.current = .errored(error)
                return .completion(.failure(error))
            case .finished, .errored, .hasRight, .hasBoth:
                fatalError("Invalid state")
        }
    }

    @Sendable static func reduceRight(state: inout State, resumption: Resumption<Void>) -> AsyncFolder<State, Action>.Effect {
        try! resumption.resume(throwing: Publishers.Error.done)
        switch (state.current) {
            case .nothing:
                state.current = .finished
                return .completion(.finished)
            case let .hasLeft(_, leftResumption):
                try! leftResumption.resume(throwing: Publishers.Error.done)
                state.current = .finished
                return .completion(.finished)
            case .finished, .errored, .hasRight, .hasBoth:
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

    @Sendable static func emit(
        _ state: inout State
    ) async throws -> Void {
        switch state.current {
            case let .hasBoth(left, leftResumption, right, rightResumption):
                let r = await AsyncResult<Void, Swift.Error> { try await state.downstream(.value((left, right))) }
                    .map {
                        try! leftResumption.resume()
                        try! rightResumption.resume()
                        return Zip<Left, Right>.Current.nothing
                    }
                    .mapError {
                        try! leftResumption.resume(throwing: $0)
                        try! rightResumption.resume(throwing: $0)
                        return $0
                    }
                state.current = try r.get()
                if case .finished = state.current { throw FinishedError() }
            case .nothing, .hasLeft, .hasRight,.finished, .errored:
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

    static func resumptions(_ current: Zip<Left, Right>.Current) -> (Resumption<Void>?, Resumption<Void>?) {
        switch current {
            case .nothing, .finished, .errored:
                return (.none, .none)
            case let .hasLeft(_, resumption):
                return (resumption, .none)
            case let .hasRight(_, resumption):
                return (.none, resumption)
            case let .hasBoth(_, lResumption, _, rResumption):
                return (lResumption, rResumption)
        }
    }

    @Sendable static func finalize(
        state: inout State,
        completion: AsyncFolder<State, Action>.Completion
    ) async {
        try? state.cancelRight()
        try? state.cancelLeft()
        let currentResumptions = resumptions(state.current)
        switch completion {
            case .finished:
                _ = try? await state.downstream(.completion(.finished))
                try? currentResumptions.0?.resume(throwing: Publishers.Error.done)
                try? currentResumptions.1?.resume(throwing: Publishers.Error.done)
            case let .failure(error):
                _ = try? await state.downstream(.completion(.failure(error)))
                try? currentResumptions.0?.resume(throwing: error)
                try? currentResumptions.1?.resume(throwing: error)
        }
        state.current = .nothing
    }

    static func folder(
        left: Publisher<Left>,
        right: Publisher<Right>,
        downstream: @Sendable @escaping (Publisher<(Left, Right)>.Result) async throws -> Void
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
