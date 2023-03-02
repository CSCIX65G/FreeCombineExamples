//
//  Errors.swift
//  
//
//  Created by Van Simmons on 3/1/23.
//

// AsyncOnce
public struct AlreadyWrittenError<T: Sendable>: Swift.Error, Sendable {
    let value: T
    init(_ value: T) { self.value = value }
}
