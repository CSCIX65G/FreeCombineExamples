//
//  Errors.swift
//  
//
//  Created by Van Simmons on 10/8/22.
//

public struct EnqueueError: Swift.Error, Sendable { }
public struct CompletionError: Swift.Error, Sendable { }
public enum AtomicError<R: RawRepresentable>: Error {
    case failedTransition(from: R, to: R, current: R?)
}
public struct LeakError: Swift.Error, Sendable { }
