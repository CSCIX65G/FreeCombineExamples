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
