//
//  Errors.swift
//  
//
//  Created by Van Simmons on 3/1/23.
//

public struct AlreadyWrittenError<T>: Swift.Error {
    let value: T
    init(_ value: T) { self.value = value }
}

extension AlreadyWrittenError: Sendable where T: Sendable { }
