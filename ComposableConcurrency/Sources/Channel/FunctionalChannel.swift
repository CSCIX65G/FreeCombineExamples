//
//  File.swift
//  
//
//  Created by Van Simmons on 2/4/23.
//
import Core

public final class FunctionalChannel<Input: Sendable, Output: Sendable>: Sendable {
    public enum Next: Sendable {
        case value(Input)
        case completion(Channels.Completion)

        func get() throws -> Input {
            switch self {
                case let .value(input): return input
                case let .completion(completion): throw completion.error
            }
        }
    }

    public func cancel(with error: Swift.Error = CancellationError()) throws -> Void {
        fatalError("cancel unimplemented")
    }

    public func close(with completion: Channels.Completion) async throws -> Void {
        fatalError("close unimplemented")
    }

    public func invoke(_ value: Input) async throws -> Output {
        fatalError("async invoke unimplemented")
    }

    public func invoke(_ value: Input) throws -> Output {
        fatalError("sync invoke unimplemented")
    }

    public func write(_ value: Input) throws -> Void {
        fatalError("sync write unimplemented")
    }

    public func read() async throws -> (Input, Resumption<Output>) {
        fatalError("async non-void read unimplemented")
    }

    public func read() async throws -> (Input) where Output == Void {
        fatalError("async void read unimplemented")
    }

    public func read() throws -> (Input, Resumption<Output>) {
        fatalError("async non-void read unimplemented")
    }

    public func read() throws -> (Input) where Output == Void {
        fatalError("async void read unimplemented")
    }
}
