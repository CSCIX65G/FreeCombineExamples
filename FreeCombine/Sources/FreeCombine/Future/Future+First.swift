//
//  Future+First.swift
//
//
//  Created by Van Simmons on 9/10/22.
//

public enum Either<Left, Right> {
    case left(Left)
    case right(Right)
}

public enum FirstAction<Left: Sendable, Right: Sendable> {
    case left(Result<Left, Swift.Error>)
    case right(Result<Right, Swift.Error>)
}

public struct FirstState<Left: Sendable, Right: Sendable> {
    enum Current {
        case nothing
        case complete(Either<Left, Right>)
        case errored(Swift.Error)
    }

    var leftCancellable: Cancellable<Void>?
    var rightCancellable: Cancellable<Void>?
    var current: Current = .nothing
}

func firstInitializer<Left: Sendable, Right: Sendable>(
    left: Future<Left>,
    right: Future<Right>
) -> (Channel<FirstAction<Left, Right>>) async -> FirstState<Left, Right> {
    { channel in
        .init(
            leftCancellable: await left { r in channel.send(.left(r)) },
            rightCancellable: await right { r in channel.send(.right(r)) }
        )
    }
}

//func firstFold<Left: Sendable, Right: Sendable>(
//    _ state: inout FirstState<Left, Right>,
//    _ action: FirstAction<Left, Right>
//) async -> Fold<FirstState<Left, Right>, FirstAction<Left, Right>>.Completion  {
//    do {
//        guard !Task.isCancelled else { throw Future<(Left, Right)>.Error.cancelled }
//        switch (action, state.current) {
//            case let (.left(leftResult), .nothing):
//                let left = try leftResult.get()
//                state.current = .complete(.left(left))
//                state.rightCancellable?.cancel()
//                state.leftCancellable = .none
//                return .done
//            case let (.right(rightResult), .nothing):
//                let right = try rightResult.get()
//                state.current = .complete(.right(right))
//                state.leftCancellable?.cancel()
//                state.leftCancellable = .none
//                return .done
//            default:
//                fatalError("Illegal state")
//        }
//    } catch {
//        state.rightCancellable?.cancel()
//        state.leftCancellable?.cancel()
//        state.current = .errored(error)
//        return .done
//    }
//}
//
//func extractFirstState<Left: Sendable, Right: Sendable>(_ state: FirstState<Left, Right>) throws -> Either<Left, Right> {
//    switch state.current {
//        case .nothing:
//            fatalError("Invalid ending fold state")
//        case let .complete(value):
//            return value
//        case let .errored(error):
//            throw error
//    }
//}
//
//public func first<Left, Right>(
//    _ left: Future<Left>,
//    _ right: Future<Right>
//) -> Future<Either<Left, Right>> {
//    Channel<FirstAction<Left, Right>>(buffering: .bufferingOldest(2))
//        .fold(initialState: firstInitializer(left: left, right: right), with: firstFold)
//        .future
//        .tryMap(extractFirstState)
//}
