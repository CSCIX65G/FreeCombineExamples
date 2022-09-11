//
//  File.swift
//  UsingFreeCombine
//
//  Created by Van Simmons on 9/5/22.
//
public func Succeeded<Output>(_ a: Output) -> Future<Output> {
    .init(a)
}

public extension Future {
    init(_ a: Output) {
        self = .init { resumption, downstream in .init {
            resumption.resume()
            return await downstream(.success(a))
        } }
    }
}

public func Succeeded<Output>(_ generator: @escaping () async -> Output) -> Future<Output> {
    .init(generator)
}

public extension Future {
    init(_ generator: @escaping () async -> Output) {
        self = .init { resumption, downstream in .init {
            resumption.resume()
            return await downstream(.success(generator()))
        } }
    }
}
