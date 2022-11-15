//
//  Publisher+Merge.swift
//  
//
//  Created by Van Simmons on 11/12/22.
//
public enum Merges {
    public enum Error: Swift.Error {
        case failure(index: Int, error: Swift.Error)
    }
}

public struct Merge<Value> {
    enum Current {
        case nothing
        case hasValue(Int, Value, Resumption<Void>)
        case errored(Int, Swift.Error)
        case finished
    }

    public struct State {
        var current: Current = .nothing
        var cancellables: [Cancellable<Void>?]
        let downstream: @Sendable (Publisher<Value>.Result) async throws -> Void

        mutating func cancel(_ index: Int) throws -> Void {
            guard let can = cancellables[index] else { throw AsyncFolders.Error.internalError }
            cancellables[index] = .none
            try can.cancel()
        }
    }

    enum Action {
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

    static func consume(_ i: Int) -> (Publisher<Value>.Result, Resumption<Void>) -> Action {
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

    static func initialize(
        upstreams: [Publisher<Value>],
        downstream: @escaping @Sendable (Publisher<Value>.Result) async throws -> Void
    ) -> (Channel<Action>) async -> State {
        { channel in
            var cancellables = ContiguousArray<Cancellable<Void>>()
            cancellables.reserveCapacity(upstreams.count)
            for i in 0 ..< upstreams.count {
                let cancellable = await channel.consume(publisher: upstreams[i], using: Self.consume(i))
                cancellables.append(cancellable)
            }
            return .init(cancellables: .init(cancellables), downstream: downstream)
        }
    }

    static func reduce(state: inout State, value: (index: Int, value: Value), resumption: Resumption<Void>) -> AsyncFolder<State, Action>.Effect {
        switch (state.current) {
            case .nothing:
                state.current = .hasValue(value.index, value.value, resumption)
                return Cancellables.isCancelled ? .completion(.failure(CancellationError())): .emit(emit)
            case .finished, .errored, .hasValue:
                fatalError("Invalid state")
        }
    }

    static func reduce(state: inout State, error: (index: Int, error: Swift.Error), resumption: Resumption<Void>) -> AsyncFolder<State, Action>.Effect {
        resumption.resume(throwing: error.error)
        switch (state.current) {
            case .nothing:
                state.current = .errored(error.index, error.error)
                return .completion(.failure(Merges.Error.failure(index: error.index, error: error.error)))
            case .finished, .errored, .hasValue:
                fatalError("Invalid state")
        }
    }

    static func reduce(state: inout State, index: Int, resumption: Resumption<Void>) -> AsyncFolder<State, Action>.Effect {
        resumption.resume(throwing: Publishers.Error.done)
        switch (state.current) {
            case .nothing:
                try? state.cancellables[index]?.cancel()
                state.cancellables[index] = .none
                return state.cancellables.allSatisfy({ $0 == nil }) ? .completion(.finished) : .none
            case .finished, .errored, .hasValue:
                fatalError("Invalid state")
        }
    }

    static func reduce(
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

    static func valuePair(_ current: Merge<Value>.Current) -> (Value, Resumption<Void>)? {
        switch current {
            case .nothing, .finished, .errored:
                return .none
            case let .hasValue(_, value, resumption):
                return (value, resumption)
        }
    }

    static func emit(
        _ state: inout State
    ) async throws -> Void {
        switch valuePair(state.current) {
            case let .some((value, resumption)):
                state.current = try await Result<Void, Swift.Error> { try await state.downstream(.value(value)) }
                    .map {
                        resumption.resume()
                        return Merge<Value>.Current.nothing
                    }
                    .mapError {
                        resumption.resume(throwing: $0)
                        return $0
                    }
                    .get()
                if case .finished = state.current { throw AsyncFolder<State, Action>.Error.finished }
            default:
                fatalError("Invalid emit state in zip")
        }
    }

    static func dispose(
        _ action: Action,
        _ completion: AsyncFolder<State, Action>.Completion
    ) async {
        var resumption: Resumption<Void>!
        switch action {
            case let .value(_, _, vResumption): resumption = vResumption
            default: ()
        }
        switch completion {
            case .finished: resumption.resume(throwing: Publishers.Error.done)
            case let .failure(error): resumption.resume(throwing: error)
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

    static func finalize(
        state: inout State,
        completion: AsyncFolder<State, Action>.Completion
    ) async {
        state.cancellables.forEach { try? $0?.cancel() }
        let resumption = resumption(state.current)
        switch completion {
            case .finished:
                _ = try? await state.downstream(.completion(.finished))
                resumption?.resume(throwing: Publishers.Error.done)
            case let .failure(error):
                _ = try? await state.downstream(.completion(.failure(error)))
                resumption?.resume(throwing: error)
        }
        state.current = .nothing
    }

    static func folder(
        publishers: [Publisher<Value>],
        downstream: @escaping @Sendable (Publisher<Value>.Result) async throws -> Void
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
