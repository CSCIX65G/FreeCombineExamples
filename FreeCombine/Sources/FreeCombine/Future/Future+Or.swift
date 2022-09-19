//
//  Future+Or.swift
//
//
//  Created by Van Simmons on 9/10/22.
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
    ) -> (Channel<Action>) async -> State {
        { channel in
                .init(
                    leftCancellable: await left { r in channel.send(.left(r)) },
                    rightCancellable: await right { r in channel.send(.right(r)) }
                )
        }
    }

    static func reduce(
        _ state: inout State,
        _ action: Action
    ) async -> Reducer<State, Action>.Effect  {
        do {
            guard !Cancellables.isCancelled else { throw Cancellables.Error.cancelled }
            switch (action, state.current) {
                case let (.left(leftResult), .nothing):
                    state.current = try .complete(.left(leftResult.get()))
                    return .completion(.exit)
                case let (.right(rightResult), .nothing):
                    state.current = try .complete(.right(rightResult.get()))
                    return .completion(.exit)
                default:
                    fatalError("Illegal state")
            }
        } catch {
            state.current = .errored(error)
            return .completion(.exit)
        }
    }

    static func dispose(
        _ action: Action,
        _ completion: Reducer<State, Action>.Completion
    ) async -> Void {

    }

    static func finalize(
        state: inout State,
        completion: Reducer<State, Action>.Completion
    ) async -> Void {
        try? state.rightCancellable?.cancel()
        state.rightCancellable = .none
        try? state.leftCancellable?.cancel()
        state.leftCancellable = .none
    }

    static func extract(state: State) throws -> Either<Left, Right> {
        switch state.current {
            case .nothing:
                throw Cancellables.Error.cancelled
            case let .complete(value):
                return value
            case let .errored(error):
                throw error
        }
    }

    static func reducer(
        left: Future<Left>,
        right: Future<Right>
    ) -> Reducer<State, Action> {
        .init(
            initializer: initialize(left: left, right: right),
            reducer: reduce,
            disposer: dispose,
            finalizer: finalize
        )
    }
}
