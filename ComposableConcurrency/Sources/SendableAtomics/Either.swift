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
