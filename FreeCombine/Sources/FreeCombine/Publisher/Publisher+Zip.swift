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
        case errored(Swift.Error)
    }

    public struct State {
        var leftCancellable: Cancellable<Demand>?
        var rightCancellable: Cancellable<Demand>?
        var current: Current = .nothing
    }

    public enum Action {
        case left(Publisher<Left>.Result, Resumption<Demand>)
        case right(Publisher<Right>.Result, Resumption<Demand>)
    }

    static func initialize(
        left: Publisher<Left>,
        right: Publisher<Right>
    ) -> (Channel<Action>) async -> State {
        { channel in
            await .init(
                leftCancellable:  channel.consume(publisher: left, using: Action.left),
                rightCancellable: channel.consume(publisher: right, using: Action.right)
            )
        }
    }

    static func reduce(
        _ state: inout State,
        _ action: Action
    ) async -> [AsyncFolder<State, Action>.Effect] {
        do {
            guard !Cancellables.isCancelled else { throw Cancellables.Error.cancelled }
            switch (action, state.current) {
                case let (.left(leftResult, leftResumption), .nothing):
                    state.current = .hasLeft(try leftResult.get(), leftResumption)
                    return [.none]
                case let (.right(rightResult, rightResumption), .nothing):
                    state.current = .hasRight(try rightResult.get(), rightResumption)
                    return [.none]
                case let (.right(rightResult, rightResumption), .hasLeft(leftValue, leftResumption)):
                    let rightValue = try rightResult.get()
                    state.current = .hasBoth(leftValue, leftResumption, rightValue, rightResumption)
                    return [.completion(.exited)]
                case let (.left(leftResult, leftResumption), .hasRight(rightValue, rightResumption)):
                    let leftValue = try leftResult.get()
                    state.current = .hasBoth(leftValue, leftResumption, rightValue, rightResumption)
                    return [.completion(.exited)]
                default:
                    fatalError("Illegal state")
            }
        } catch {
            state.current = .errored(error)
            return [.completion(.exited)]
        }
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
                throw Cancellables.Error.cancelled
            case let .hasBoth(leftValue, _, rightValue, _):
                return (leftValue, rightValue)
            case let .errored(error):
                throw error
        }
    }

    static func folder(
        left: Publisher<Left>,
        right: Publisher<Right>
    ) -> AsyncFolder<State, Action> {
        .init(
            initializer: initialize(left: left, right: right),
            reducer: reduce,
            disposer: dispose,
            finalizer: finalize
        )
    }
}
