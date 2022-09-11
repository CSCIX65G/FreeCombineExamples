//
//  Failed.swift
//  UsingFreeCombine
//
//  Created by Van Simmons on 9/5/22.
//
public func Failed<Output>(
    _ type: Output.Type = Output.self,
    error: Swift.Error
) -> Future<Output> {
    .init(type, error: error)
}

public extension Future {
    init(
        _ type: Output.Type = Output.self,
        error: Swift.Error
    ) {
        self = .init { resumption, downstream in .init {
            resumption.resume()
            return await downstream(.failure(error))
        } }
    }
}

public func Fail<Output>(
    _ type: Output.Type = Output.self,
    generator: @escaping () async -> Swift.Error
) -> Future<Output> {
    .init(type, generator: generator)
}

public extension Future {
    init(
         _ type: Output.Type = Output.self,
         generator: @escaping () async -> Swift.Error
    ) {
        self = .init { resumption, downstream in  .init {
            resumption.resume()
            return await downstream(.failure(generator()))
        } }
    }
}
