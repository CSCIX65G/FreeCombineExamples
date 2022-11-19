//
//  CurrentValueSubject.swift
//  
//
//  Created by Van Simmons on 11/18/22.
//
public func CurrentValueSubject<Output>(
    function: StaticString = #function,
    file: StaticString = #file,
    line: UInt = #line,
    type: Output.Type = Output.self,
    buffering: AsyncStream<Output>.Continuation.BufferingPolicy = .bufferingOldest(1),
    onStartup: Resumption<Void>,
    _ initialValue: Output
) async throws -> Subject<Output> {
    try await .init(buffering: buffering, initialValue: initialValue)
}

public func CurrentValueSubject<Output>(
    function: StaticString = #function,
    file: StaticString = #file,
    line: UInt = #line,
    type: Output.Type = Output.self,
    buffering: AsyncStream<Output>.Continuation.BufferingPolicy = .bufferingOldest(1),
    _ initialValue: Output
) async throws -> Subject<Output> {
    try await .init(buffering: buffering, initialValue: initialValue)
}
