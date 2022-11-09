//
//  Publisher+Zip.swift
//
//
//  Created by Van Simmons on 9/6/22.
//

public struct Zip<Left, Right> {
    public typealias Demand = Publishers.Demand
    enum Current {
        case nothing
        case hasLeft(Left, Resumption<Demand>)
        case hasRight(Right, Resumption<Demand>)
        case hasBoth(Left, Resumption<Demand>, Right, Resumption<Demand>)
        case completed
        case errored(Swift.Error)
    }

    enum Error: Swift.Error {
        case invalidState(Current)
    }

    public struct State {
        var leftCancellable: Cancellable<Demand>?
        var rightCancellable: Cancellable<Demand>?
        var current: Current = .nothing
        let downstream: @Sendable (Publisher<(Left, Right)>.Result) async throws -> Demand
    }

    public enum Action {
        case left(Publisher<Left>.Result, Resumption<Demand>)
        case right(Publisher<Right>.Result, Resumption<Demand>)
    }

    static func initialize(
        left: Publisher<Left>,
        right: Publisher<Right>,
        downstream: @escaping @Sendable (Publisher<(Left, Right)>.Result) async throws -> Demand
    ) -> (Channel<Action>) async -> State {
        { channel in
            await .init(
                leftCancellable:  channel.consume(publisher: left, using: Action.left),
                rightCancellable: channel.consume(publisher: right, using: Action.right),
                downstream: downstream
            )
        }
    }

    static func reduceLeft(state: inout State, value: Left, resumption: Resumption<Demand>) -> [AsyncFolder<State, Action>.Effect] {
        switch (state.current) {
            case .nothing:
                state.current = .hasLeft(value, resumption)
                return Cancellables.isCancelled ? [.completion(.exited)] : []
            case let .hasRight(rightValue, rightResumption):
                state.current = .hasBoth(value, resumption, rightValue, rightResumption)
                return [.emit(emit)]
            case .completed, .errored:
                try? state.leftCancellable?.cancel()
                state.leftCancellable = .none
                resumption.resume(returning: .done)
                return [.completion(.exited)]
            case .hasLeft, .hasBoth:
                fatalError("Invalid state")
        }
    }
    static func reduceLeft(state: inout State, error: Swift.Error, resumption: Resumption<Demand>) -> [AsyncFolder<State, Action>.Effect] {
        try? state.leftCancellable?.cancel()
        state.leftCancellable = .none
        resumption.resume(returning: .done)
        switch (state.current) {
            case .nothing:
                state.current = .errored(error)
                return [.emit(emit)]
            case let .hasRight(_, rightResumption):
                try? state.rightCancellable?.cancel()
                state.rightCancellable = .none
                rightResumption.resume(throwing: error)
                state.current = .errored(error)
                return [.emit(emit), .completion(.failure(error))]
            case .completed, .errored:
                return [.completion(.exited)]
            case .hasLeft, .hasBoth:
                fatalError("Invalid state")
        }
    }
    static func reduceLeft(state: inout State, resumption: Resumption<Demand>) -> [AsyncFolder<State, Action>.Effect] {
        try? state.leftCancellable?.cancel()
        state.leftCancellable = .none
        resumption.resume(returning: .done)
        switch (state.current) {
            case .nothing:
                state.current = .completed
                return [.emit(emit)]
            case let .hasRight(_, rightResumption):
                try? state.rightCancellable?.cancel()
                state.rightCancellable = .none
                rightResumption.resume(returning: .done)
                state.current = .completed
                return [.emit(emit), .completion(.finished)]
            case .completed, .errored:
                return [.completion(.exited)]
            case .hasLeft, .hasBoth:
                fatalError("Invalid state")
        }
    }
    static func reduceRight(state: inout State, value: Right, resumption: Resumption<Demand>) -> [AsyncFolder<State, Action>.Effect] {
        switch (state.current) {
            case .nothing:
                state.current = .hasRight(value, resumption)
                return Cancellables.isCancelled ? [.completion(.exited)] : []
            case let .hasLeft(leftValue, leftResumption):
                state.current = .hasBoth(leftValue, leftResumption, value, resumption)
                return [.emit(emit)]
            case .completed, .errored:
                try? state.rightCancellable?.cancel()
                state.rightCancellable = .none
                resumption.resume(returning: .done)
                return [.completion(.exited)]
            case .hasRight, .hasBoth:
                fatalError("Invalid state")
        }
    }
    static func reduceRight(state: inout State, error: Swift.Error, resumption: Resumption<Demand>) -> [AsyncFolder<State, Action>.Effect] {
        try? state.rightCancellable?.cancel()
        state.rightCancellable = .none
        resumption.resume(returning: .done)
        switch (state.current) {
            case .nothing:
                state.current = .errored(error)
                return [.emit(emit)]
            case let .hasLeft(_, leftResumption):
                try? state.leftCancellable?.cancel()
                state.leftCancellable = .none
                leftResumption.resume(throwing: error)
                state.current = .errored(error)
                return [.emit(emit), .completion(.failure(error))]
            case .completed, .errored:
                return [.completion(.exited)]
            case .hasRight, .hasBoth:
                fatalError("Invalid state")
        }
    }
    static func reduceRight(state: inout State, resumption: Resumption<Demand>) -> [AsyncFolder<State, Action>.Effect] {
        try? state.rightCancellable?.cancel()
        state.rightCancellable = .none
        resumption.resume(returning: .done)
        switch (state.current) {
            case .nothing:
                state.current = .completed
                return [.emit(emit)]
            case let .hasLeft(_, leftResumption):
                try? state.leftCancellable?.cancel()
                state.leftCancellable = .none
                leftResumption.resume(returning: .done)
                state.current = .completed
                return [.emit(emit), .completion(.finished)]
            case .completed, .errored:
                return [.completion(.exited)]
            case .hasRight, .hasBoth:
                fatalError("Invalid state")
        }
    }

    static func reduce(
        _ state: inout State,
        _ action: Action
    ) async -> [AsyncFolder<State, Action>.Effect] {
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

    static func emit(
        _ state: inout State
    ) async throws -> Void {
        switch state.current {
            case let .hasBoth(left, leftResumption, right, rightResumption):
                let result = try await state.downstream(.value((left, right)))
                state.current = .nothing
                leftResumption.resume(returning: result)
                rightResumption.resume(returning: result)
            case .completed:
                _ = try await state.downstream(.completion(.finished))
            case let .errored(error):
                _ = try await state.downstream(.completion(.failure(error)))
            case .nothing, .hasLeft, .hasRight:
                fatalError("Invalid emit state in zip")
        }
    }

    static func dispose(
        _ action: Action,
        _ completion: AsyncFolder<State, Action>.Completion
    ) async {
        switch action {
            case let .left(_, resumption):
                switch completion {
                    case .finished, .exited: resumption.resume(returning: .done)
                    case let .failure(error): resumption.resume(throwing: error)
                }
            case let .right(_, resumption):
                switch completion {
                    case .finished, .exited: resumption.resume(returning: .done)
                    case let .failure(error): resumption.resume(throwing: error)
                }
        }
    }

    static func finalize(
        state: inout State,
        completion: AsyncFolder<State, Action>.Completion
    ) async {
        switch state.current {
            case .nothing:
                ()
            case let .hasLeft(_, resumption):
                resumption.resume(throwing: CancellationError())
            case let .hasRight(_, resumption):
                resumption.resume(throwing: CancellationError())
            case let .hasBoth(_, lResumption, _, rResumption):
                lResumption.resume(throwing: CancellationError())
                rResumption.resume(throwing: CancellationError())
            case .completed, .errored:
                ()
        }
        try? state.rightCancellable?.cancel()
        state.rightCancellable = .none
        try? state.leftCancellable?.cancel()
        state.leftCancellable = .none
        state.current = .nothing
    }

    static func extract(state: State) throws -> (Left, Right) {
        switch state.current {
            case .nothing, .hasLeft, .hasRight:
                throw CancellationError()
            case let .hasBoth(leftValue, _, rightValue, _):
                return (leftValue, rightValue)
            case let .errored(error):
                throw error
            case .completed:
                throw CancellationError()
        }
    }

    static func folder(
        left: Publisher<Left>,
        right: Publisher<Right>,
        downstream: @escaping @Sendable (Publisher<(Left, Right)>.Result) async throws -> Demand
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
