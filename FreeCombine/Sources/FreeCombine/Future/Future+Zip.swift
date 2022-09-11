//
//  Future+Zip.swift
//
//
//  Created by Van Simmons on 9/6/22.
//

public enum ZipAction<Left: Sendable, Right: Sendable> {
    case left(Result<Left, Swift.Error>)
    case right(Result<Right, Swift.Error>)
}

public struct ZipState<Left: Sendable, Right: Sendable> {
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

func zipInitializer<Left: Sendable, Right: Sendable>(
    left: Future<Left>,
    right: Future<Right>
) -> (Channel<ZipAction<Left, Right>>) async -> ZipState<Left, Right> {
    { channel in
        .init(
            leftCancellable: await left { r in channel.send(.left(r)) },
            rightCancellable: await right { r in channel.send(.right(r)) }
        )
    }
}

func zipFold<Left: Sendable, Right: Sendable>(
    _ state: inout ZipState<Left, Right>,
    _ action: ZipAction<Left, Right>
) async -> Fold<ZipState<Left, Right>, ZipAction<Left, Right>>.Completion  {
    do {
        guard !Task.isCancelled else { throw Future<(Left, Right)>.Error.cancelled }
        switch (action, state.current) {
            case let (.left(leftResult), .nothing):
                state.current = .hasLeft(try leftResult.get())
                state.leftCancellable = .none
                return .more
            case let (.right(rightResult), .nothing):
                state.current = .hasRight(try rightResult.get())
                state.rightCancellable = .none
                return .more
            case let (.right(rightResult), .hasLeft(leftValue)):
                let rightValue = try rightResult.get()
                state.current = .complete(leftValue, rightValue)
                state.rightCancellable = .none
                return .done
            case let (.left(leftResult), .hasRight(rightValue)):
                let leftValue = try leftResult.get()
                state.current = .complete(leftValue, rightValue)
                state.leftCancellable = .none
                return .done
            default:
                fatalError("Illegal state")
        }
    } catch {
        state.rightCancellable?.cancel()
        state.leftCancellable?.cancel()
        state.current = .errored(error)
        return .done
    }
}

func extractZipState<Left: Sendable, Right: Sendable>(_ state: ZipState<Left, Right>) throws -> (Left, Right) {
    switch state.current {
        case .nothing, .hasLeft, .hasRight:
            fatalError("Invalid ending fold state")
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
    Channel<ZipAction<Left, Right>>(buffering: .bufferingOldest(2))
        .fold(initialState: zipInitializer(left: left, right: right), with: zipFold)
        .future
        .tryMap(extractZipState)
}
