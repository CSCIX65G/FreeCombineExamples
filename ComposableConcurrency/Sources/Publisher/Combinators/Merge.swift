//
//  Publisher+Merge.swift
//  
//
//  Created by Van Simmons on 11/12/22.
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

public enum Merges {
    public enum Error: Swift.Error, Sendable {
        case failure(index: Int, error: Swift.Error)
    }
}

public struct Merge<Value: Sendable>: Sendable {
    enum Current: Sendable {
        case nothing
        case hasValue(Int, Value, Resumption<Void>)
        case errored(Int, Swift.Error)
        case finished
    }

    public struct State: Sendable {
        var current: Current = .nothing
        var cancellables: [Int: Cancellable<Void>]
        let downstream: @Sendable (Publisher<Value>.Result) async throws -> Void

        mutating func cancel(_ id: Int) throws -> Void {
            guard let can = cancellables[id] else { throw MergeCancellationFailureError(id: id) }
            cancellables[id] = .none
            try can.cancel()
            cancellables.removeValue(forKey: id)
        }
    }

    enum Action: Sendable {
        case value(Int, Value, Resumption<Void>)
        case finish(Int, Resumption<Void>)
        case failure(Int, Error, Resumption<Void>)
        var resumption: Resumption<Void> {
            switch self {
                case .value(_, _, let resumption): return resumption
                case .finish(_, let resumption): return resumption
                case .failure(_, _, let resumption): return resumption
            }
        }
    }

    @Sendable static func consume(_ i: Int) -> @Sendable (Publisher<Value>.Result, Resumption<Void>) -> Action {
        { result, resumption in
            switch result {
                case let .value(value):
                    return .value(i, value, resumption)
                case .completion(.finished):
                    return .finish(i, resumption)
                case let .completion(.failure(error)):
                    return .failure(i, error, resumption)
            }
        }
    }

    @Sendable static func initialize(
        upstreams: [Publisher<Value>],
        downstream: @Sendable @escaping (Publisher<Value>.Result) async throws -> Void
    ) -> @Sendable (Queue<Action>) async -> State {
        { channel in
            var cancellables = [Int: Cancellable<Void>]()
            cancellables.reserveCapacity(upstreams.count)
            for i in 0 ..< upstreams.count {
                let cancellable = await channel.consume(publisher: upstreams[i], using: Self.consume(i))
                cancellables[i] = cancellable
            }
            return .init(cancellables: cancellables, downstream: downstream)
        }
    }

    @Sendable static func reduce(state: inout State, value: (index: Int, value: Value), resumption: Resumption<Void>) -> AsyncFolder<State, Action>.Effect {
        switch (state.current) {
            case .nothing:
                state.current = .hasValue(value.index, value.value, resumption)
                return Task.isCancelled ? .completion(.failure(CancellationError())): .none
            case .finished, .errored, .hasValue:
                fatalError("Invalid state")
        }
    }

    @Sendable static func reduce(state: inout State, error: (index: Int, error: Swift.Error), resumption: Resumption<Void>) -> AsyncFolder<State, Action>.Effect {
        try! resumption.resume(throwing: error.error)
        switch (state.current) {
            case .nothing:
                state.current = .errored(error.index, error.error)
                return .completion(.failure(Merges.Error.failure(index: error.index, error: error.error)))
            case .finished, .errored, .hasValue:
                fatalError("Invalid state")
        }
    }

    @Sendable static func reduce(state: inout State, index: Int, resumption: Resumption<Void>) -> AsyncFolder<State, Action>.Effect {
        try! resumption.resume(throwing: Publishers.Error.done)
        switch (state.current) {
            case .nothing:
                try? state.cancel(index)
                return state.cancellables.isEmpty ? .completion(.finished) : .none
            case .finished, .errored, .hasValue:
                fatalError("Invalid state")
        }
    }

    @Sendable static func reduce(
        _ state: inout State,
        _ action: Action
    ) async -> AsyncFolder<State, Action>.Effect {
        switch (action) {
            case let (.value(index, value, resumption)):
                return reduce(state: &state, value: (index: index, value: value), resumption: resumption)
            case let (.failure(index, error, resumption)):
                return reduce(state: &state, error: (index: index, error: error), resumption: resumption)
            case let (.finish(index, resumption)):
                return reduce(state: &state, index: index, resumption: resumption)
        }
    }

    @Sendable static func valuePair(_ current: Merge<Value>.Current) -> (Value, Resumption<Void>)? {
        switch current {
            case .nothing, .finished, .errored:
                return .none
            case let .hasValue(_, value, resumption):
                return (value, resumption)
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
                    return Merge<Value>.Current.nothing
                }
                .mapError {
                    try! resumption.resume(throwing: $0)
                    return $0
                }
                .get()
                if case .finished = state.current {
                    throw FinishedError()
                }
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
            case let .value(_, _, vResumption): resumption = vResumption
            default: ()
        }
        switch completion {
            case .finished: try! resumption.resume(throwing: Publishers.Error.done)
            case let .failure(error): try! resumption.resume(throwing: error)
        }
    }

    static func resumption(_ current: Merge<Value>.Current) -> Resumption<Void>? {
        switch current {
            case .nothing, .finished, .errored:
                return .none
            case let .hasValue(_, _, resumption):
                return resumption
        }
    }

    @Sendable static func finalize(
        state: inout State,
        completion: AsyncFolder<State, Action>.Completion
    ) async {
        state.cancellables.forEach { _, cancellable in try? cancellable.cancel() }
        let resumption = resumption(state.current)
        switch completion {
            case .finished:
                _ = try? await state.downstream(.completion(.finished))
                do { try resumption?.resume(throwing: Publishers.Error.done) }
                catch { fatalError("Failed resumption") }
            case let .failure(error):
                _ = try? await state.downstream(.completion(.failure(error)))
                do { try resumption?.resume(throwing: error) }
                catch { fatalError("Failed resumption with error: \(error)") }
        }
        state.current = .nothing
    }

    @Sendable static func folder(
        publishers: [Publisher<Value>],
        downstream: @Sendable @escaping (Publisher<Value>.Result) async throws -> Void
    ) -> AsyncFolder<State, Action> {
        .init(
            initializer: initialize(upstreams: publishers, downstream: downstream),
            reducer: reduce,
            emitter: emit,
            disposer: dispose,
            finalizer: finalize
        )
    }
}
