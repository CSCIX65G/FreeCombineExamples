//
//  Errors.swift
//  
//
//  Created by Van Simmons on 10/8/22.
//

public struct CompletionError: Swift.Error, Sendable { }
public struct CancellationFailureError: Swift.Error, Sendable { }

public struct LeakError: Swift.Error, Sendable { }

public enum AtomicError<R: RawRepresentable>: Error {
    case failedTransition(from: R, to: R, current: R?)
}

public enum EnqueueError<Element>: Error {
    case dropped(Element)
    case terminated
}
