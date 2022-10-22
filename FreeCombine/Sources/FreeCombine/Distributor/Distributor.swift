//
//  Distributor.swift
//  
//
//  Created by Van Simmons on 10/15/22.
//
public struct Distributor<Output: Sendable> {
//    typealias StreamId = StreamId
//    typealias Repeater = IdentifiedRepeater<StreamId, Output, Void>
//
//    private enum SubscriptionAction: Sendable {
//        case subscribe(Repeater, Resumption<Output>, Resumption<StreamId>)
//        case unsubscribe(StreamId)
//    }
//
//    private enum UpstreamAction: Sendable {
//        case value(Output, Resumption<Void>)
//        case subscription(action: SubscriptionAction)
//    }
//
//    private let valueChannel: Channel<Output>
//    private let valueCancellable: Cancellable<Void>
//
//    private let subscriptionChannel: Channel<SubscriptionAction>
//    private let subscriptionCancellable: Cancellable<Void>
//
//    private let upstreamChannel: Channel<UpstreamAction>
//    private let upstreamCancellable: Cancellable<Void>
//
//    private let downstreamReturnChannel: Channel<Repeater.Next>
//
//    public init(
//        buffering: AsyncStream<Output>.Continuation.BufferingPolicy = .bufferingOldest(1)
//    ) {
//        // Initialize from downstream upward
//        downstreamReturnChannel = Channel<Repeater.Next>(buffering: .unbounded)
//        (upstreamChannel, upstreamCancellable) = Self.createUpstreams(returnChannel: downstreamReturnChannel)
//        (valueChannel, valueCancellable) = Self.createReceivers(upstreamChannel: upstreamChannel)
//        (subscriptionChannel, subscriptionCancellable) = Self.createSubscription(upstreamChannel: upstreamChannel)
//    }
//
//    private static func createUpstreams(
//        returnChannel: Channel<Repeater.Next>
//    ) -> (Channel<UpstreamAction>, Cancellable<Void>) {
//        var iterator = returnChannel.stream.makeAsyncIterator()
//        let upstreamChannel = Channel<UpstreamAction>.init(buffering: .unbounded)
//        let cancellable = Cancellable<Void> { await withTaskCancellationHandler(
//            operation: {
//                var nextStreamId = StreamId.zero
//                var repeaters: [StreamId: (repeater: Repeater, resumption: Resumption<Output>)] = [:]
//                for await action in upstreamChannel.stream {
//                    switch action {
//                        case let .value(value, upstreamResumption):
//                            let numRepeaters = repeaters.count
//                            // Send the value
//                            for (_, (_, resumption)) in repeaters { resumption.resume(returning: value) }
//                            // Gather the returns
//                            for _ in 0 ..< numRepeaters {
//                                guard let next = await iterator.next() else { fatalError("Invalid stream") }
//                                guard let repeater = repeaters[next.id]?.repeater else { fatalError("Lost repeater") }
//                                guard case let .success(value) = next.result else {
//                                    repeaters.removeValue(forKey: next.id)
//                                    repeater.cancellable.cancel()
//                                    continue
//                                }
//                                repeaters[next.id] = (repeater, next.resumption)
//                            }
//                        case let .subscription(action: .subscribe(repeater, resumption)):
//                            repeaters[nextStreamId] = (repeater: repeater, resumption: resumption)
//                            try! resumption.tryResume(returning: nextStreamId)
//                            nextStreamId += 1
//                        case let .subscription(action: .unsubscribe(streamId)):
//                            try? repeaters.removeValue(forKey: streamId)?
//                                .dispatchReturn
//                                .tryResume(throwing: CancellationError())
//                    }
//                }
//            },
//            onCancel: {
//
//            }
//        ) }
//        return (upstreamChannel, cancellable)
//    }
//
//    private static func createReceivers(
//        buffering: AsyncStream<Output>.Continuation.BufferingPolicy = .bufferingOldest(1),
//        upstreamChannel: Channel<UpstreamAction>
//    ) -> (Channel<Output>, Cancellable<Void>) {
//        let channel = Channel<Output>.init(buffering: buffering)
//        let cancellable = Cancellable<Void>(operation: { try await withTaskCancellationHandler (
//            operation: {
//                for await output in channel.stream { try await withResumption { resumption in
//                    do { try upstreamChannel.tryYield(.value(output, resumption )) }
//                    catch { }
//                } }
//            },
//            onCancel: {
//
//            }
//        ) } )
//        return (channel, cancellable)
//    }
//
//    private static func createSubscription(
//        upstreamChannel: Channel<UpstreamAction>
//    ) -> (Channel<SubscriptionAction>, Cancellable<Void>) {
//        let channel = Channel<SubscriptionAction>.init(buffering: .unbounded)
//        let cancellable = Cancellable<Void>(operation: { await withTaskCancellationHandler (
//            operation: {
//                for await action in channel.stream {
//                    do { try upstreamChannel.tryYield(.subscription(action: action)) }
//                    catch { }
//                }
//            },
//            onCancel: {
//
//            }
//        ) } )
//        return (channel, cancellable)
//    }
//
//    func subscribe(
//        resumption: Resumption<StreamId>,
//        operation: @escaping @Sendable (Publisher<Output>.Result) async throws -> Publishers.Demand
//    ) {
//
//    }
//
//    func subscribe(
//        operation: @escaping @Sendable (Publisher<Output>.Result) async throws -> Publishers.Demand
//    ) async throws -> StreamId {
//        return try await withResumption { resumption in
//            subscribe(resumption: resumption, operation: operation)
//        }
//    }
//
//    func unsubscribe(
//        streamId: StreamId
//    ) {
//
//    }
}
