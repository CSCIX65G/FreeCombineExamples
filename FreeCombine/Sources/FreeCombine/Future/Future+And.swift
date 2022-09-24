//
//  Future+And.swift
//
//
//  Created by Van Simmons on 9/6/22.
//

public struct And<Left, Right> {
    enum Current {
        case nothing
        case hasLeft(Left)
        case hasRight(Right)
        case complete(Left, Right)
        case errored(Swift.Error)
    }

    public struct State {
        var leftCancellable: Cancellable<Void>?
        var rightCancellable: Cancellable<Void>?
        var current: Current = .nothing
    }

    public enum Action {
        case left(Result<Left, Swift.Error>)
        case right(Result<Right, Swift.Error>)
    }

    static func initialize(
        left: Future<Left>,
        right: Future<Right>
    ) -> (Channel<Action>) async -> State {
        { channel in
            .init(
                leftCancellable: await left { channel.send(.left($0)) },
                rightCancellable: await right { channel.send(.right($0)) }
            )
        }
    }

    static func reduce(
        _ state: inout State,
        _ action: Action
    ) async -> Folder<State, Action>.Effect {
        do {
            guard !Cancellables.isCancelled else { throw Cancellables.Error.cancelled }
            switch (action, state.current) {
                case let (.left(leftResult), .nothing):
                    state.current = .hasLeft(try leftResult.get())
                    return .none
                case let (.right(rightResult), .nothing):
                    state.current = .hasRight(try rightResult.get())
                    return .none
                case let (.right(rightResult), .hasLeft(leftValue)):
                    let rightValue = try rightResult.get()
                    state.current = .complete(leftValue, rightValue)
                    return .completion(.exit)
                case let (.left(leftResult), .hasRight(rightValue)):
                    let leftValue = try leftResult.get()
                    state.current = .complete(leftValue, rightValue)
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
        _ completion: Folder<State, Action>.Completion
    ) async {

    }

    static func finalize(
        state: inout State,
        completion: Folder<State, Action>.Completion
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
            case let .complete(leftValue, rightValue):
                return (leftValue, rightValue)
            case let .errored(error):
                throw error
        }
    }

    static func folder(
        left: Future<Left>,
        right: Future<Right>
    ) -> Folder<State, Action> {
        .init(
            initializer: initialize(left: left, right: right),
            reducer: reduce,
            disposer: dispose,
            finalizer: finalize
        )
    }
}
