//
//  Publishers.swift
//  
//
//  Created by Van Simmons on 9/19/22.
//
public enum Publishers {
    public enum Error: Swift.Error {
        case done
    }

    public enum Completion: Sendable {
        case failure(Swift.Error)
        case finished
    }
}
