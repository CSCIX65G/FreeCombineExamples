//
//  Either.swift
//  
//
//  Created by Van Simmons on 9/18/22.
//
public enum Either<Left, Right> {
    case left(Left)
    case right(Right)
}

