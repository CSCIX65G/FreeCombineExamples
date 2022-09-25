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
            await .init(
                leftCancellable: channel.consume(future: left, using: Action.left),
                rightCancellable: channel.consume(future: right, using: Action.right)
            )
        }
    }

    static func reduce(
        _ state: inout State,
        _ action: Action
    ) async -> AsyncFolder<State, Action>.Effect  {
        do {
            guard !Cancellables.isCancelled else { throw Cancellables.Error.cancelled }
            switch (action, state.current) {
                case let (.left(leftResult), .nothing):
                    state.current = try .complete(.left(leftResult.get()))
                    return .completion(.exited)
                case let (.right(rightResult), .nothing):
                    state.current = try .complete(.right(rightResult.get()))
                    return .completion(.exited)
                default:
                    fatalError("Illegal state")
            }
        } catch {
            state.current = .errored(error)
            return .completion(.exited)
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
                throw Cancellables.Error.cancelled
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
