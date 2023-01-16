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
    let completion: Channels.Completion
}
public struct ChannelCompleteError: Error {
    let completion: Channels.Completion
}
public struct ChannelDroppedValueError<Value>: Error {
    let value: Value
}
public struct ChannelDroppedResumptionError: Error { }
