//
//  Subject.swift
//
//
//  Created by Van Simmons on 6/28/22.
//
//  Copyright 2022, ComputeCycles, LLC
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//
import Core
import Queue

public final class Subject<Output: Sendable> {
    private let function: StaticString
    private let file: StaticString
    private let line: UInt
    private let distributor: Distributor<Output>

    init(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        buffering: AsyncStream<Output>.Continuation.BufferingPolicy = .bufferingOldest(1),
        initialValue: Output? = .none
    ) {
        self.function = function
        self.file = file
        self.line = line
        distributor = .init(buffering: buffering, initialValue: initialValue)
    }
}

public extension Subject {
    @Sendable
    func yield(_ value: Output) throws {
        try distributor.send(value)
    }

    @Sendable
    func send(_ result: Publisher<Output>.Result) async throws {
        switch result {
            case let .value(value):
                return try await distributor.send(value)
            case let .completion(completion):
                return try await distributor.finish(completion)
        }
    }

    @Sendable
    func send(_ value: Output) async throws {
        try await distributor.send(value)
    }

    @Sendable
    func cancel() throws -> Void {
        try distributor.cancel()
    }

    @Sendable
    func finish(_ completion: Publishers.Completion = .finished) throws {
        try distributor.finish(completion)
    }

    @Sendable
    func finish(_ completion: Publishers.Completion = .finished) async throws {
        try await distributor.finish(completion)
    }

    @Sendable
    func fail(_ error: Error) async throws {
        try await distributor.finish(.failure(error))
    }

    var value: Void {
        get async throws { _ = try await distributor.result.get() }
    }

    var result: AsyncResult<Void, Swift.Error> {
        get async {
            switch await distributor.result {
                case .success: return .success(())
                case .failure: return .failure(Publishers.Error.done)
            }
        }
    }
}

public extension Publisher {
    init(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        distributor: Distributor<Output>
    ) {
        self = .init { resumption, downstream in
            Cancellable<Cancellable<Void>> {
                let cancellable = try await distributor.subscribe { result in
                    _ = try await downstream(result)
                }
                resumption.resume()
                return cancellable
            }.join()
        }
    }
}

public extension Subject {
    var asyncPublisher: Publisher<Output> {
        publisher()
    }

    func publisher(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line
    ) -> Publisher<Output> {
        .init(
            function: function,
            file: file,
            line: line,
            distributor: distributor
        )
    }
}
