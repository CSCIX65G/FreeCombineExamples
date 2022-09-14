//
//  Future+Zip.swift
//
//
//  Created by Van Simmons on 9/6/22.
//

public struct ZipState<Left: Sendable, Right: Sendable> {
    public enum Action {
        case left(Result<Left, Swift.Error>)
        case right(Result<Right, Swift.Error>)
    }

    enum Current {
        case nothing
        case hasLeft(Left)
        case hasRight(Right)
        case complete(Left, Right)
        case errored(Swift.Error)
    }

    var leftCancellable: Cancellable<Void>?
    var rightCancellable: Cancellable<Void>?
    var current: Current = .nothing
}

func zipInitialize<Left: Sendable, Right: Sendable>(
    left: Future<Left>,
    right: Future<Right>
) -> (Channel<ZipState<Left, Right>.Action>) async -> ZipState<Left, Right> {
    { channel in
        .init(
            leftCancellable: await left { channel.send(.left($0)) },
            rightCancellable: await right { channel.send(.right($0)) }
        )
    }
}

func zipReduce<Left: Sendable, Right: Sendable>(
    _ state: inout ZipState<Left, Right>,
    _ action: ZipState<Left, Right>.Action
) async -> Reducer<ZipState<Left, Right>, ZipState<Left, Right>.Action>.Effect  {
    do {
        guard !Task.isCancelled else { throw Cancellables.Error.cancelled }
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

func zipDispose<Left: Sendable, Right: Sendable>(
    _ action: ZipState<Left, Right>.Action,
    _ completion: Reducer<ZipState<Left, Right>, ZipState<Left, Right>.Action>.Completion
) async -> Void {

}

func zipFinalize<Left: Sendable, Right: Sendable>(
    state: inout ZipState<Left, Right>,
    completion: Reducer<ZipState<Left, Right>, ZipState<Left, Right>.Action>.Completion
) async -> Void {
    try? state.rightCancellable?.cancel()
    state.rightCancellable = .none
    try? state.leftCancellable?.cancel()
    state.leftCancellable = .none
}

func extractZipState<Left: Sendable, Right: Sendable>(_ state: ZipState<Left, Right>) throws -> (Left, Right) {
    switch state.current {
        case .nothing, .hasLeft, .hasRight:
            throw Cancellables.Error.cancelled
        case let .complete(leftValue, rightValue):
            return (leftValue, rightValue)
        case let .errored(error):
            throw error
    }
}

public func zip<Left, Right>(
    _ left: Future<Left>,
    _ right: Future<Right>
) -> Future<(Left, Right)> {
    .init { resumption, downstream in .init {
        do {
            let channel = Channel<ZipState<Left, Right>.Action>(buffering: .bufferingOldest(2))
            try await withTaskCancellationHandler(
                operation: {
                    try await downstream(.success(extractZipState(
                        await channel.fold(
                            onStartup: resumption,
                            into: .init(
                                initializer: zipInitialize(left: left, right: right),
                                reducer: zipReduce,
                                disposer: zipDispose,
                                finalizer: zipFinalize
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
