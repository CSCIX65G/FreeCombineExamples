//
//  File.swift
//  
//
//  Created by Van Simmons on 12/10/22.
//

public enum Queues {
    public enum Error: Swift.Error {
        case done
    }

    public enum Completion: Sendable {
        case failure(Swift.Error)
        case finished

        public var error: Swift.Error {
            get {
                switch self {
                    case .finished: return FinishedError()
                    case let .failure(error): return error
                }
            }
        }
    }
}
