//
//  Future+Select.swift
//
//
//  Created by Van Simmons on 9/10/22.
//

public enum Either<Left, Right> {
    case left(Left)
    case right(Right)
}

public struct SelectState<Left: Sendable, Right: Sendable> {
    public enum Action {
        case left(Result<Left, Swift.Error>)
        case right(Result<Right, Swift.Error>)
    }

    enum Current {
        case nothing
        case complete(Either<Left, Right>)
        case errored(Swift.Error)
    }

    var leftCancellable: Cancellable<Void>?
    var rightCancellable: Cancellable<Void>?
    var current: Current = .nothing
}

func selectInitialize<Left: Sendable, Right: Sendable>(
    left: Future<Left>,
    right: Future<Right>
) -> (Channel<SelectState<Left, Right>.Action>) async -> SelectState<Left, Right> {
    { channel in
        .init(
            leftCancellable: await left { r in channel.send(.left(r)) },
            rightCancellable: await right { r in channel.send(.right(r)) }
        )
    }
}

func selectReduce<Left: Sendable, Right: Sendable>(
    _ state: inout SelectState<Left, Right>,
    _ action: SelectState<Left, Right>.Action
) async -> Reducer<SelectState<Left, Right>, SelectState<Left, Right>.Action>.Effect  {
    do {
        guard !Task.isCancelled else { throw Cancellable<(Left, Right)>.Error.cancelled }
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

func selectDispose<Left: Sendable, Right: Sendable>(
    _ action: SelectState<Left, Right>.Action,
    _ completion: Reducer<SelectState<Left, Right>, SelectState<Left, Right>.Action>.Completion
) async -> Void {

}

func selectFinalize<Left: Sendable, Right: Sendable>(
    state: inout SelectState<Left, Right>,
    completion: Reducer<SelectState<Left, Right>, SelectState<Left, Right>.Action>.Completion
) async -> Void {
    state.rightCancellable?.cancel()
    state.rightCancellable = .none
    state.leftCancellable?.cancel()
    state.leftCancellable = .none
}

func extractSelectState<Left: Sendable, Right: Sendable>(_ state: SelectState<Left, Right>) throws -> Either<Left, Right> {
    switch state.current {
        case .nothing:
            throw Cancellable<Either<Left, Right>>.Error.cancelled
        case let .complete(value):
            return value
        case let .errored(error):
            throw error
    }
}

public func select<Left, Right>(
    _ left: Future<Left>,
    _ right: Future<Right>
) -> Future<Either<Left, Right>> {
    .init { resumption, downstream in .init {
        do {
            let channel = Channel<SelectState<Left, Right>.Action>(buffering: .bufferingOldest(2))
            try await withTaskCancellationHandler(
                operation: {
                    try await downstream(.success(extractSelectState(
                        await channel.fold(
                            onStartup: resumption,
                            into: .init(
                                initializer: selectInitialize(left: left, right: right),
                                reducer: selectReduce,
                                disposer: selectDispose,
                                finalizer: selectFinalize
                            )
                        ).value
                    )))
                },
                onCancel: {
                    channel.finish()
                }
            )
        } catch {
            return await downstream(.failure(error))
        }
    } }
}
