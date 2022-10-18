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
        case subscribe(AsyncStream<DownstreamDispatch>.Continuation, Resumption<StreamId>)
        case unsubscribe(StreamId)
    }

    private enum UpstreamAction: Sendable {
        case value(Output, Resumption<Void>)
        case subscription(action: SubscriptionAction)
    }

    class Repeater {
        let continuation: AsyncStream<DownstreamDispatch>.Continuation
        var nextResumption: Resumption<Result<Void, Swift.Error>>!
        public private(set) var cancellable: Cancellable<Void>!
        init(
            streamId: StreamId,
            continuation: AsyncStream<DownstreamDispatch>.Continuation,
            resultChannel: Channel<DownstreamReturn>
        ) {
            self.continuation = continuation
            self.nextResumption = .none
            self.cancellable = .init {
                var result = Result<Void, Swift.Error>.success(())
                while true {
                    guard case .success = result else {
                        try! resultChannel.tryYield((streamId, result, .none))
                        return try result.get()
                    }
                    result = try await withResumption { resumption in
                        self.nextResumption = resumption
                        try! resultChannel.tryYield((streamId, result, resumption))
                    }
                }
            }
        }
    }

    private let receiveChannel: Channel<Output>
    private let receiveCancellable: Cancellable<Void>

    private let subscriptionChannel: Channel<SubscriptionAction>
    private let subscriptionCancellable: Cancellable<Void>

    private let upstreamChannel: Channel<UpstreamAction>
    private let upstreamCancellable: Cancellable<Void>

    private let downstreamReturnChannel: Channel<DownstreamReturn>
    private let downstreamReturnCancellable: Cancellable<Void>

    public init(
        buffering: AsyncStream<Output>.Continuation.BufferingPolicy = .bufferingOldest(1)
    ) {
        (downstreamReturnChannel, downstreamReturnCancellable) = Self.createDownstreams()
        (upstreamChannel, upstreamCancellable) = Self.createUpstreams(downstreamChannel: downstreamReturnChannel)
        (receiveChannel, receiveCancellable) = Self.createReceivers(upstreamChannel: upstreamChannel)
        (subscriptionChannel, subscriptionCancellable) = Self.createSubscription(upstreamChannel: upstreamChannel)
    }

    private static func createDownstreams(
    ) -> (Channel<DownstreamReturn>, Cancellable<Void>) {
        let channel = Channel<DownstreamReturn>(buffering: .unbounded)
        let cancellable = Cancellable<Void> { await withTaskCancellationHandler(
            operation: {

            },
            onCancel: {

            })
        }
        return (channel, cancellable)
    }

    private static func handleValue(
        repeaters: inout [UInt64 : Distributor<Output>.Repeater],
        value: Output,
        downstreamChannel: Channel<DownstreamReturn>,
        upstreamResumption: Resumption<Void>
    ) async {
        // Send the values
        for (streamId, repeater) in repeaters {
            do { try repeater.continuation.tryYield((value, repeater.nextResumption)) }
            catch { repeaters.removeValue(forKey: streamId) }
        }
        var count = 0, max = repeaters.count
        // wait for the returns
        for await (streamId, result, nextResumption) in downstreamChannel.stream {
            guard count < max else { break }
            count += 1
            switch result {
                case .success():
                    repeaters[streamId]!.nextResumption = nextResumption!
                case let .failure(error):
                    repeaters.removeValue(forKey: streamId)
                    try? nextResumption?.tryResume(throwing: error)
            }
        }
        upstreamResumption.resume()
    }

    private static func createUpstreams(
        downstreamChannel: Channel<DownstreamReturn>
    ) -> (Channel<UpstreamAction>, Cancellable<Void>) {
        let channel = Channel<UpstreamAction>.init(buffering: .unbounded)
        let cancellable = Cancellable<Void> { await withTaskCancellationHandler(
            operation: {
                var nextStreamId = UInt64.zero
                var repeaters = [StreamId: Repeater]()
                for await action in channel.stream {
                    switch action {
                        case let .value(value, upstreamResumption):
                            await handleValue(
                                repeaters: &repeaters,
                                value: value,
                                downstreamChannel: downstreamChannel,
                                upstreamResumption: upstreamResumption
                            )
                        case let .subscription(action: .subscribe(continuation, resumption)):
                            repeaters[nextStreamId] = Repeater.init(
                                streamId: nextStreamId,
                                continuation: continuation,
                                resultChannel: downstreamChannel
                            )
                            try! resumption.tryResume(returning: nextStreamId)
                            nextStreamId += 1
                        case let .subscription(action: .unsubscribe(streamId)):
                            try? repeaters.removeValue(forKey: streamId)?
                                .nextResumption
                                .tryResume(throwing: CancellationError())
                    }
                }
            },
            onCancel: {

            }
        ) }
        return (channel, cancellable)
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
}
