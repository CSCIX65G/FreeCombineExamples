//
//  File.swift
//  
//
//  Created by Van Simmons on 12/10/22.
//
import Queue
import Future

public extension AsyncFold {
    var publisher: Publisher<State> {
        future.publisher
    }
}
