//
//  Distributor.swift
//  
//
//  Created by Van Simmons on 10/15/22.
//
public struct Distributor<Output: Sendable> {
    public typealias StreamId = UInt64
    public typealias DownstreamDispatch = (Output, Resumption<Result<Void, Swift.Error>>)
    public typealias DownstreamReturn = (StreamId, Result<Void, Swift.Error>, Resumption<Result<Void, Swift.Error>>?)

    private enum SubscriptionAction: Sendable {
        case subscribe(Channel<DownstreamDispatch>, Resumption<StreamId>)
        case unsubscribe(StreamId)
    }

    private enum UpstreamAction: Sendable {
        case value(Output, Resumption<Void>)
        case subscription(action: SubscriptionAction)
    }

    private let valueChannel: Channel<Output>
    private let valueCancellable: Cancellable<Void>

    private let subscriptionChannel: Channel<SubscriptionAction>
    private let subscriptionCancellable: Cancellable<Void>

    private let upstreamChannel: Channel<UpstreamAction>
    private let upstreamCancellable: Cancellable<Void>

    private let downstreamReturnChannel: Channel<DownstreamReturn>

    public init(
        buffering: AsyncStream<Output>.Continuation.BufferingPolicy = .bufferingOldest(1)
    ) {
        // Initialize from downstream upward
        downstreamReturnChannel = Channel<DownstreamReturn>(buffering: .unbounded)
        (upstreamChannel, upstreamCancellable) = Self.createUpstreams(returnChannel: downstreamReturnChannel)
        (valueChannel, valueCancellable) = Self.createReceivers(upstreamChannel: upstreamChannel)
        (subscriptionChannel, subscriptionCancellable) = Self.createSubscription(upstreamChannel: upstreamChannel)
    }

    private static func dispatchValue(
        value: Output,
        repeaters: inout [UInt64 : Distributor<Output>.Repeater]
    ) {
        // Send the values
        for (streamId, repeater) in repeaters {
            do {
                try repeater.dispatchChannel.tryYield((value, repeater.dispatchReturn))
            }
            catch {
                try? repeaters.removeValue(forKey: streamId)?.dispatchReturn.tryResume(throwing: error)
            }
        }
    }

    private static func handleValue(
        repeaters: inout [UInt64 : Distributor<Output>.Repeater],
        value: Output,
        returnChannel: Channel<DownstreamReturn>,
        upstreamResumption: Resumption<Void>
    ) async {
        var count = 0, max = repeaters.count
        dispatchValue(value: value, repeaters: &repeaters)
        // wait for the returns
        for await (streamId, result, nextResumption) in returnChannel.stream {
            guard count < max else { break }
            count += 1
            switch result {
                case .success():
                    repeaters[streamId]!.dispatchReturn = nextResumption!
                case let .failure(error):
                    repeaters.removeValue(forKey: streamId)
                    try? nextResumption?.tryResume(throwing: error)
            }
        }
        upstreamResumption.resume()
    }

    private static func createUpstreams(
        returnChannel: Channel<DownstreamReturn>
    ) -> (Channel<UpstreamAction>, Cancellable<Void>) {
        let upstreamChannel = Channel<UpstreamAction>.init(buffering: .unbounded)
        let cancellable = Cancellable<Void> { await withTaskCancellationHandler(
            operation: {
                var nextStreamId = UInt64.zero
                var repeaters = [StreamId: Repeater]()
                for await action in upstreamChannel.stream {
                    switch action {
                        case let .value(value, upstreamResumption):
                            await handleValue(
                                repeaters: &repeaters,
                                value: value,
                                returnChannel: returnChannel,
                                upstreamResumption: upstreamResumption
                            )
                        case let .subscription(action: .subscribe(dispatchChannel, resumption)):
                            repeaters[nextStreamId] = Repeater.init(
                                streamId: nextStreamId,
                                dispatchChannel: dispatchChannel,
                                returnChannel: returnChannel
                            )
                            try! resumption.tryResume(returning: nextStreamId)
                            nextStreamId += 1
                        case let .subscription(action: .unsubscribe(streamId)):
                            try? repeaters.removeValue(forKey: streamId)?
                                .dispatchReturn
                                .tryResume(throwing: CancellationError())
                    }
                }
            },
            onCancel: {

            }
        ) }
        return (upstreamChannel, cancellable)
    }

    private static func createReceivers(
        buffering: AsyncStream<Output>.Continuation.BufferingPolicy = .bufferingOldest(1),
        upstreamChannel: Channel<UpstreamAction>
    ) -> (Channel<Output>, Cancellable<Void>) {
        let channel = Channel<Output>.init(buffering: buffering)
        let cancellable = Cancellable<Void>(operation: { try await withTaskCancellationHandler (
            operation: {
                for await output in channel.stream { try await withResumption { resumption in
                    do { try upstreamChannel.tryYield(.value(output, resumption )) }
                    catch { }
                } }
            },
            onCancel: {

            }
        ) } )
        return (channel, cancellable)
    }

    private static func createSubscription(
        upstreamChannel: Channel<UpstreamAction>
    ) -> (Channel<SubscriptionAction>, Cancellable<Void>) {
        let channel = Channel<SubscriptionAction>.init(buffering: .unbounded)
        let cancellable = Cancellable<Void>(operation: { await withTaskCancellationHandler (
            operation: {
                for await action in channel.stream {
                    do { try upstreamChannel.tryYield(.subscription(action: action)) }
                    catch { }
                }
            },
            onCancel: {

            }
        ) } )
        return (channel, cancellable)
    }

    func subscribe(
        resumption: Resumption<StreamId>,
        operation: @escaping @Sendable (Publisher<Output>.Result) async throws -> Publishers.Demand
    ) {

    }

    func subscribe(
        operation: @escaping @Sendable (Publisher<Output>.Result) async throws -> Publishers.Demand
    ) async throws -> StreamId {
        return try await withResumption { resumption in
            subscribe(resumption: resumption, operation: operation)
        }
    }

    func unsubscribe(
        streamId: StreamId
    ) {

    }
}

// Repeater carries the dispatchChannel and nextResumption for use by the distributor
//     dispatchChannel houses the downstream function for this subscriber
//     dispatchReturn awaits the return from the downstream function
extension Distributor {
    class Repeater {
        let dispatchChannel: Channel<DownstreamDispatch>
        var dispatchReturn: Resumption<Result<Void, Swift.Error>>!
        public private(set) var cancellable: Cancellable<Void>!

        init(
            streamId: StreamId,
            dispatchChannel: Channel<DownstreamDispatch>,
            returnChannel: Channel<DownstreamReturn>
        ) {
            self.dispatchChannel = dispatchChannel
            self.dispatchReturn = .none
            self.cancellable = .init {
                var result = Result<Void, Swift.Error>.success(())
                while true {
                    guard case .success = result else {
                        try! returnChannel.tryYield((streamId, result, .none))
                        self.dispatchReturn = .none
                        return try result.get()
                    }
                    result = try await withResumption { resumption in
                        self.dispatchReturn = resumption
                        try! returnChannel.tryYield((streamId, result, resumption))
                    }
                }
            }
        }
    }
}
