//
//  Distributor.swift
//  
//
//  Created by Van Simmons on 10/15/22.
//
public final class Distributor<Output: Sendable> {
    typealias Repeater = IdentifiedRepeater<UInt64, Output, Void>

    private enum SubscriptionAction: Sendable {
        case subscribe(Repeater, Resumption<Publisher<Output>.Result>, Resumption<UInt64>)
        case unsubscribe(UInt64)
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

    private let returnChannel: Channel<Repeater.Next>

    private var nextId = UInt64.zero

    public init(
        buffering: AsyncStream<Output>.Continuation.BufferingPolicy = .bufferingOldest(1)
    ) {
        // Initialize from downstream upward
        returnChannel = Channel<Repeater.Next>(buffering: .unbounded)
        (upstreamChannel, upstreamCancellable) = Self.createUpstreams(returnChannel: returnChannel)
        (valueChannel, valueCancellable) = Self.createValueReceiver(upstreamChannel: upstreamChannel)
        (subscriptionChannel, subscriptionCancellable) = Self.createSubscriptionReceiver(upstreamChannel: upstreamChannel)
    }

    private static func createUpstreams(
        returnChannel: Channel<Repeater.Next>
    ) -> (Channel<UpstreamAction>, Cancellable<Void>) {
        let upstreamChannel = Channel<UpstreamAction>.init(buffering: .unbounded)
        let cancellable = Cancellable<Void> {
            var iterator = returnChannel.stream.makeAsyncIterator()
            var repeaters: [UInt64: (repeater: Repeater, resumption: Resumption<Publisher<Output>.Result>)] = [:]
            for await action in upstreamChannel {
                switch action {
                    case let .value(value, upstreamResumption):
                        let numRepeaters = repeaters.count
                        // Send the value
                        for (_, (_, resumption)) in repeaters { resumption.resume(returning: .value(value)) }
                        // Gather the returns
                        for _ in 0 ..< numRepeaters {
                            guard let next = await iterator.next() else { fatalError("Invalid stream") }
                            guard let repeater = repeaters[next.id]?.repeater else { fatalError("Lost repeater") }
                            guard case .success = next.result else {
                                repeaters.removeValue(forKey: next.id)
                                try? repeater.cancellable.cancel()
                                continue
                            }
                            repeaters[next.id] = (repeater, next.resumption)
                        }
                        do { try upstreamResumption.tryResume() }
                        catch { fatalError("Unhandled value resumption") }
                    case let .subscription(action: .subscribe(repeater, returnResumption, idResumption)):
                        repeaters[repeater.id] = (repeater: repeater, resumption: returnResumption)
                        do { try idResumption.tryResume(returning: repeater.id) }
                        catch { fatalError("Unhandled subscription resumption") }
                    case let .subscription(action: .unsubscribe(streamId)):
                        try? repeaters.removeValue(forKey: streamId)?
                            .resumption
                            .tryResume(throwing: CancellationError())
                }
            }
            for (_, (repeater, _)) in repeaters { try? repeater.cancellable.cancel() }
            repeaters = [:]
        }
        return (upstreamChannel, cancellable)
    }

    private static func createValueReceiver(
        buffering: AsyncStream<Output>.Continuation.BufferingPolicy = .bufferingOldest(1),
        upstreamChannel: Channel<UpstreamAction>
    ) -> (Channel<Output>, Cancellable<Void>) {
        let channel = Channel<Output>.init(buffering: buffering)
        let cancellable = Cancellable<Void> {
            for await output in channel.stream { try await withResumption { resumption in
                do { try upstreamChannel.tryYield(.value(output, resumption )) }
                catch { channel.finish() }
            } }
        }
        return (channel, cancellable)
    }

    private static func createSubscriptionReceiver(
        buffering: AsyncStream<SubscriptionAction>.Continuation.BufferingPolicy = .unbounded,
        upstreamChannel: Channel<UpstreamAction>
    ) -> (Channel<SubscriptionAction>, Cancellable<Void>) {
        let channel = Channel<SubscriptionAction>.init(buffering: buffering)
        let cancellable = Cancellable<Void>(operation: { await withTaskCancellationHandler (
            operation: {
                for await action in channel.stream {
                    do { try upstreamChannel.tryYield(.subscription(action: action)) }
                    catch { }
                }
            },
            onCancel: {
                channel.finish()
            }
        ) } )
        return (channel, cancellable)
    }

    public func subscribe(
        operation: @escaping @Sendable (Publisher<Output>.Result) async throws -> Void
    ) async throws -> Cancellable<Void> {
        let id = UInt64.random(in: 0 ..< UInt64.max)
        let first = await Repeater.first(id: id, dispatch: operation, returnChannel: returnChannel)
        let compare: UInt64 = try await withResumption({ idResumption in
            do { try subscriptionChannel.tryYield(.subscribe(first.repeater, first.resumption, idResumption)) }
            catch { try! idResumption.tryResume(throwing: SubscriptionError()) }
        })
        guard compare == id else { throw SubscriptionError() }
        return .init { try await withTaskCancellationHandler(
            operation: {
                try await self.upstreamCancellable.value
            },
            onCancel: {
                try? self.subscriptionChannel.tryYield(.unsubscribe(id))
            }
        ) }
    }

    public func send(_ value: Output) throws {
        try valueChannel.tryYield(value)
    }

    func finish() {
        subscriptionChannel.finish()
        valueChannel.finish()
        upstreamChannel.finish()
        returnChannel.finish()
    }

    var result: Result<Void, Swift.Error> {
        get async {
            _ = await valueCancellable.result
            _ = await subscriptionCancellable.result
            return await upstreamCancellable.result
        }
    }
}
