//
//  File.swift
//  
//
//  Created by Van Simmons on 12/10/22.
//
import Future
public extension Promise {
    var publisher: Publisher<Output> {
        future.publisher
    }
}
