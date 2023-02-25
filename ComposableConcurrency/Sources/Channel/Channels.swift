//
//  Channels.swift
//  
//
//  Created by Van Simmons on 1/20/23.
//

public enum Channels {
    public enum Buffering: Sendable {
        case oldest(Int)
        case newest(Int)
        case unbounded
    }

    public enum Error: Swift.Error {
        case done
    }

    public enum Completion: Sendable {
        case finished
        case failure(Swift.Error)

        public var error: Swift.Error {
            get {
                switch self {
                    case .finished: return Channels.Error.done
                    case let .failure(error): return error
                }
            }
        }
    }
}

