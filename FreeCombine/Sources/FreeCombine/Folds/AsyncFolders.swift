//
//  File.swift
//  
//
//  Created by Van Simmons on 9/25/22.
//

public enum AsyncFolders { }

public extension AsyncFolders {
    enum Completion {
        case exited
        case failure(Swift.Error)
        case finished
    }

    enum Error: Swift.Error {
        case cancelled
        case completed
        case finished
    }
}
