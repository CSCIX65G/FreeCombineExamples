//
//  Distributor.swift
//  
//
//  Created by Van Simmons on 10/15/22.
//
public final class Distributor<Output: Sendable> {
    private let function: StaticString
    private let file: StaticString
    private let line: UInt

    let returnChannel: Channel<ConcurrentFunc<Output, Void>.Next>
    let valueFold: AsyncFold<ValueState, ValueAction>
    let distributionFold: AsyncFold<DistributionState, DistributionAction>

    public init(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        buffering: AsyncStream<Output>.Continuation.BufferingPolicy = .bufferingOldest(1)
    ) {
        self.function = function
        self.file = file
        self.line = line

        returnChannel = Channel<ConcurrentFunc<Output, Void>.Next>(buffering: .unbounded)

        distributionFold = Channel<DistributionAction>.init(buffering: .unbounded)
            .fold(into: Self.distributionFolder(returnChannel: returnChannel))
        
        valueFold = Channel<ValueAction>.init(buffering: buffering)
            .fold(into: Self.valueFolder(mainChannel: distributionFold.channel))
    }
}

public extension Distributor {
    func subscribe(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        operation: @escaping @Sendable (Publisher<Output>.Result) async throws -> Void
    ) -> Cancellable<Cancellable<Void>> {
        .init { try await self.subscribe(function: function, file: file, line: line, operation: operation) }
    }

    func subscribe(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        operation: @escaping @Sendable (Publisher<Output>.Result) async throws -> Void
    ) async throws -> Cancellable<Void> {
        let invocation: ConcurrentFunc<Output, Void>.Invocation = await .init(
            originatingFunction: function,
            file: file,
            line: line,
            dispatch: operation,
            returnChannel: returnChannel
        )
        let subscriptionId: ObjectIdentifier = try await withResumption({ idResumption in
            do { try distributionFold.send(.subscribe(invocation.function, invocation.resumption, idResumption)) }
            catch { try? idResumption.tryResume(throwing: SubscriptionError()) }
        })

        return .init(function: function, file: file, line: line) { try await withTaskCancellationHandler(
            operation: { _ = try await invocation.function.cancellable.value },
            onCancel: { try? self.distributionFold.send(.unsubscribe(subscriptionId)) }
        ) }
    }

    func send(_ value: Output) throws {
        try valueFold.send(.asyncValue(value))
    }

    func send(_ value: Output) async throws {
        try await withResumption { resumption in
            do { try valueFold.send(.syncValue(value, resumption)) }
            catch { resumption.resume(throwing: BufferError()) }
        }
    }

    func finish(_ completion: Publishers.Completion = .finished) async throws {
        _ = try await withResumption { resumption in
            do { try valueFold.send(.syncCompletion(completion, resumption)) }
            catch { resumption.resume(throwing: error) }
        }
        valueFold.finish()
        _ = await valueFold.result
        returnChannel.finish()
        distributionFold.finish()
        _ = try await distributionFold.value
    }

    func finish(_ completion: Publishers.Completion = .finished) throws {
        try valueFold.send(.asyncCompletion(completion))
    }

    var result: Result<DistributionState, Swift.Error> {
        get async { await distributionFold.result }
    }
}
