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
        case leftCompleted
        case rightCompleted
        case bothCompleted
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

    static func reduce(
        _ state: inout State,
        _ action: Action
    ) async -> [AsyncFolder<State, Action>.Effect] {
        do {
            guard !Cancellables.isCancelled else { throw CancellationError() }
            switch (action, state.current) {
                case let (.left(leftResult, leftResumption), .nothing):
                    switch leftResult {
                        case let .value(value):
                            state.current = .hasLeft(value, leftResumption)
                            return [.none]
                        case let .completion(.failure(error)):
                            state.current = .errored(error)
                            return [.emit(emit)]
                        case .completion(.finished):
                            state.current = .leftCompleted
                            leftResumption.resume(returning: .done)
                            return [.emit(emit)]
                    }
                case let (.right(rightResult, rightResumption), .nothing):
                    state.current = .hasRight(try rightResult.get(), rightResumption)
                    return [.none]
                case let (.right(rightResult, rightResumption), .hasLeft(leftValue, leftResumption)):
                    let rightValue = try rightResult.get()
                    state.current = .hasBoth(leftValue, leftResumption, rightValue, rightResumption)
                    return [.emit(emit)]
                case let (.left(leftResult, leftResumption), .hasRight(rightValue, rightResumption)):
                    let leftValue = try leftResult.get()
                    state.current = .hasBoth(leftValue, leftResumption, rightValue, rightResumption)
                    return [.emit(emit)]
                default:
                    fatalError("Illegal state")
            }
        } catch {
            state.current = .errored(error)
            return [.completion(.exited)]
        }
    }

    static func emit(
        _ state: inout State
    ) async throws -> Void {
        guard case let .hasBoth(left, leftResumption, right, rightResumption) = state.current else {
            Assertion.assertionFailure("bad zip state")
            throw Error.invalidState(state.current)
        }
        let result = try await state.downstream(.value((left, right)))
        state.current = .nothing
        leftResumption.resume(returning: result)
        rightResumption.resume(returning: result)
    }

    static func dispose(
        _ action: Action,
        _ completion: AsyncFolder<State, Action>.Completion
    ) async {

    }

    static func finalize(
        state: inout State,
        completion: AsyncFolder<State, Action>.Completion
    ) async {
        try? state.rightCancellable?.cancel()
        state.rightCancellable = .none
        try? state.leftCancellable?.cancel()
        state.leftCancellable = .none
    }

    static func extract(state: State) throws -> (Left, Right) {
        switch state.current {
            case .nothing, .hasLeft, .hasRight:
                throw CancellationError()
            case let .hasBoth(leftValue, _, rightValue, _):
                return (leftValue, rightValue)
            case let .errored(error):
                throw error
            case .leftCompleted:
                throw CancellationError()
            case .rightCompleted:
                throw CancellationError()
            case .bothCompleted:
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
