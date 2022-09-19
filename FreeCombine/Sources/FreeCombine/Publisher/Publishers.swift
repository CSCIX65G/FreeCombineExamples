//
//  Publishers.swift
//  
//
//  Created by Van Simmons on 9/19/22.
//
public enum Publishers {
    public enum Demand: Equatable, Sendable {
        case more
        case done
    }

    public enum Completion: Sendable {
        case failure(Swift.Error)
        case finished
    }

    public enum Error: Swift.Error {
        case cancelled
        case completed
        case internalError
        case enqueueError
    }
}
