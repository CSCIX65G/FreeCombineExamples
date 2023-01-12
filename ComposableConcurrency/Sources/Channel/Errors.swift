//
//  Errors.swift
//  
//
//  Created by Van Simmons on 12/26/22.
//

public struct FailedReadError: Error { }
public struct FailedWriteError: Error { }
public struct ChannelOccupiedError: Error { }
public struct ChannelCancellationFailureError: Error {
    let error: Error
}
public struct ChannelDroppedError<Value>: Error {
    let value: Value
}
