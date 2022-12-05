//
//  Distributor.swift
//  
//
//  Created by Van Simmons on 10/15/22.
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

public struct SubscriptionError: Swift.Error, Sendable, Equatable { }

public final class Distributor<Output: Sendable> {
    private let function: StaticString
    private let file: StaticString
    private let line: UInt

    let returnChannel: Queue<ConcurrentFunc<Output, Void>.Next>
    let valueFold: AsyncFold<ValueState, ValueAction>
    let distributionFold: AsyncFold<DistributionState, DistributionAction>

    public init(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        buffering: AsyncStream<Output>.Continuation.BufferingPolicy = .bufferingOldest(1),
        initialValue: Output? = .none
    ) {
        self.function = function
        self.file = file
        self.line = line

        returnChannel = Queue<ConcurrentFunc<Output, Void>.Next>(buffering: .unbounded)

        distributionFold = Queue<DistributionAction>.init(buffering: .unbounded)
            .fold(
                function: function,
                file: file,
                line: line,
                into: Self.distributionFolder(currentValue: initialValue, returnChannel: returnChannel)
            )
        
        valueFold = Queue<ValueAction>.init(buffering: buffering)
            .fold(
                function: function,
                file: file,
                line: line,
                into: Self.valueFolder(mainChannel: distributionFold.channel)
            )
    }
}

public extension Distributor {
    func subscribe(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        operation: @escaping @Sendable (Publisher<Output>.Result) async throws -> Void
    ) -> Cancellable<Cancellable<Void>> {
        .init {
          try await self.subscribe(function: function, file: file, line: line, operation: operation)
        }
    }

    func subscribe(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        operation: @escaping @Sendable (Publisher<Output>.Result) async throws -> Void
    ) async throws -> Cancellable<Void> {
        let invocation: ConcurrentFunc<Output, Void> = await .init(
            function: function,
            file: file,
            line: line,
            operation
        )
        let subscriptionId: ObjectIdentifier = try await pause { idResumption in
            do { try distributionFold.send(.subscribe(invocation, idResumption)) }
            catch { try? idResumption.tryResume(throwing: SubscriptionError()) }
        }

        return .init(function: function, file: file, line: line) {
            try await withTaskCancellationHandler(
                operation: {
                    switch await invocation.dispatch.cancellable.result {
                        case let .failure(error) where !(error is CompletionError):
                            throw error
                        default:
                            return
                    }
                },
                onCancel: {
                    try? self.distributionFold.send(.cancel(subscriptionId))
                }
            )
        }
    }

    func send(_ value: Output) throws {
        try valueFold.send(.asyncValue(.value(value)))
    }

    func send(_ value: Output) async throws {
        try await pause { resumption in
            do { try valueFold.send(.syncValue(.value(value), resumption)) }
            catch { resumption.resume(throwing: error) }
        }
    }

    func cancel() throws -> Void {
        try valueFold.send(.asyncCompletion(.failure(CancellationError())))
        valueFold.finish()
        returnChannel.finish()
        distributionFold.finish()
    }

    func finish(_ completion: Publishers.Completion = .finished) async throws {
        _ = try await pause { resumption in
            do { try valueFold.send(.syncCompletion(completion, resumption)) }
            catch { resumption.resume(throwing: error) }
        }
        valueFold.finish()
        _ = await valueFold.result
        returnChannel.finish()
        distributionFold.finish()
        _ = await distributionFold.result
    }

    func finish(_ completion: Publishers.Completion = .finished) throws {
        try valueFold.send(.asyncCompletion(completion))
    }

    var result: AsyncResult<DistributionState, Swift.Error> {
        get async { await distributionFold.result }
    }
}
