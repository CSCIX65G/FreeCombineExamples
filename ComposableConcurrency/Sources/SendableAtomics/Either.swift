//
//  File.swift
//  
//
//  Created by Van Simmons on 2/28/23.
//

public enum Either<Left, Right> {
    case left(Left)
    case right(Right)
}

extension Either: Sendable where Left: Sendable, Right: Sendable { }

public extension Either {
    @Sendable static func sendableLeft(_ value: Left) -> Self where Left: Sendable {
        .left(value)
    }
    @Sendable static func sendableRight(_ value: Right) -> Self where Right: Sendable {
        .right(value)
    }
}

public extension Either {
    @Sendable func mapLeft<NewLeft>(
        _ transform: (Left) -> NewLeft
    ) -> Either<NewLeft, Right> {
        switch self {
            case let .left(leftValue): return .left(transform(leftValue))
            case let .right(rightValue): return .right(rightValue)
        }
    }

    @Sendable func flatMapLeft<NewLeft>(
        _ transform: (Left) -> Either<NewLeft, Right>
    ) -> Either<NewLeft, Right> {
        switch self {
            case let .left(leftValue): return transform(leftValue)
            case let .right(rightValue): return .right(rightValue)
        }
    }

    @Sendable func mapRight<NewRight>(
        _ transform: (Right) -> NewRight
    ) -> Either<Left, NewRight> {
        switch self {
            case let .left(leftValue): return .left(leftValue)
            case let .right(rightValue): return .right(transform(rightValue))
        }
    }

    @Sendable func flatMapRight<NewRight>(
        _ transform: (Right) async -> Either<Left, NewRight>
    ) async -> Either<Left, NewRight> {
        switch self {
            case let .left(leftValue): return .left(leftValue)
            case let .right(rightValue): return await transform(rightValue)
        }
    }
}
