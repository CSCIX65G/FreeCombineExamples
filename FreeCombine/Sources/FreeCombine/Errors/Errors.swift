//
//  Errors.swift
//  
//
//  Created by Van Simmons on 10/8/22.
//
import Atomics

public struct CompletionError: Swift.Error, Sendable {
    let completion: Publishers.Completion
}
public struct CancellationFailureError: Swift.Error, Sendable, Equatable { }

public struct ReleaseError: Swift.Error, Sendable, Equatable { }
public struct LeakError: Swift.Error, Sendable, Equatable { }
public struct TimeoutError: Swift.Error, Sendable, Equatable { }
public struct BufferError: Swift.Error, Sendable, Equatable { }
public struct SubscriptionError: Swift.Error, Sendable, Equatable { }
public struct InvocationError: Swift.Error, Sendable, Equatable { }

public enum AtomicError<R: AtomicValue>: Error {
    case failedTransition(from: R, to: R, current: R)
}

public enum EnqueueError<Element: Sendable>: Error {
    case dropped(Element)
    case terminated
}
