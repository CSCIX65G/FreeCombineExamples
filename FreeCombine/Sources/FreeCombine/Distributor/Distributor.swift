//
//  Distributor.swift
//  
//
//  Created by Van Simmons on 10/15/22.
//
public final class Distributor<Output: Sendable> {
    typealias Repeater = IdentifiedRepeater<UInt64, Output, Void>
    typealias RepeaterDictionary = [UInt64 : (repeater: IdentifiedRepeater<UInt64, Output, ()>, resumption: Resumption<Publisher<Output>.Result>)]
    typealias ReturnIterator = AsyncStream<IdentifiedRepeater<UInt64, Output, ()>.Next>.Iterator

    private enum ValueAction: Sendable {
        case synchronousValue(Output)
        case asynchronousValue(Output, Resumption<Void>)
    }

    private enum SubscriptionAction: Sendable {
        case subscribe(Repeater, Resumption<Publisher<Output>.Result>, Resumption<UInt64>)
        case unsubscribe(UInt64)
    }

    private enum UpstreamAction: Sendable, CustomStringConvertible {
        case value(Output, Resumption<Void>)
        case subscription(action: SubscriptionAction)
        var description: String {
            switch self {
                case let .value(value, _): return "Value: \(value)"
                case let .subscription(action: .subscribe(repeater, _, _)): return "Subscribe: \(repeater.id)"
                case let .subscription(action: .unsubscribe(id)): return "Unsubscribe: \(id)"
            }
        }
    }

    private let function: StaticString
    private let file: StaticString
    private let line: UInt

    private let valueChannel: Channel<ValueAction>
    private let valueCancellable: Cancellable<Void>

    private let subscriptionChannel: Channel<SubscriptionAction>
    private let subscriptionCancellable: Cancellable<Void>

    private let upstreamChannel: Channel<UpstreamAction>
    private let upstreamCancellable: Cancellable<Void>

    private let returnChannel: Channel<Repeater.Next>

    public init(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        buffering: AsyncStream<Output>.Continuation.BufferingPolicy = .bufferingOldest(1)
    ) {
        self.function = function
        self.file = file
        self.line = line
        // Initialize from downstream upward
        returnChannel = Channel<Repeater.Next>(buffering: .unbounded)
        (upstreamChannel, upstreamCancellable) = Self.createUpstreams(returnChannel: returnChannel)
        (valueChannel, valueCancellable) = Self.createValueReceiver(buffering: buffering, upstreamChannel: upstreamChannel)
        (subscriptionChannel, subscriptionCancellable) = Self.createSubscriptionReceiver(upstreamChannel: upstreamChannel)
    }

    // Send a value to all subscribers
    static func processValue(
        _ value: Output,
        _ repeaters: inout RepeaterDictionary,
        _ iterator: inout ReturnIterator,
        _ upstreamResumption: Resumption<Void>
    ) async {
        for (_, (_, resumption)) in repeaters { resumption.resume(returning: .value(value)) }
        for _ in 0 ..< repeaters.count {
            guard let next = await iterator.next() else { fatalError("Invalid stream") }
            guard let repeater = repeaters[next.id]?.repeater else { fatalError("Lost repeater") }
            switch next.result {
                case let .failure(error):
                    next.resumption.resume(throwing: error)
                    _ = await repeater.cancellable.result
                    repeaters.removeValue(forKey: next.id)
                    continue
                case .success:
                    repeaters[next.id] = (repeater, next.resumption)
            }
        }
        do { try upstreamResumption.tryResume() }
        catch { fatalError("Unhandled value resumption") }
    }

    private static func createUpstreams(
        returnChannel: Channel<Repeater.Next>
    ) -> (Channel<UpstreamAction>, Cancellable<Void>) {
        let upstreamChannel = Channel<UpstreamAction>.init(buffering: .unbounded)
        let cancellable = Cancellable<Void> {
            var iterator = returnChannel.stream.makeAsyncIterator()
            var repeaters: RepeaterDictionary = [:]
            for await action in upstreamChannel {
                switch action {
                    case let .value(value, upstreamResumption):
                        await processValue(value, &repeaters, &iterator, upstreamResumption)
                    case let .subscription(action: .subscribe(repeater, returnResumption, idResumption)):
                        guard repeaters[repeater.id] == nil else {
                            fatalError("duplicate key: \(repeater.id)") 
                        }
                        repeaters[repeater.id] = (repeater: repeater, resumption: returnResumption)
                        do { try idResumption.tryResume(returning: repeater.id) }
                        catch { fatalError("Unhandled subscription resumption") }
                    case let .subscription(action: .unsubscribe(streamId)):
                        guard let pair = repeaters.removeValue(forKey: streamId) else {
                            continue
                        }
                        try! pair.resumption.tryResume(throwing: CancellationError())
                        _ = await pair.repeater.cancellable.result
                }
            }
            for (_, (repeater, resumption)) in repeaters {
                resumption.resume(returning: .completion(.finished))
                _ = await repeater.cancellable.result
            }
            repeaters = [:]
        }
        return (upstreamChannel, cancellable)
    }

    private static func createValueReceiver(
        buffering: AsyncStream<Output>.Continuation.BufferingPolicy = .bufferingOldest(1),
        upstreamChannel: Channel<UpstreamAction>
    ) -> (Channel<ValueAction>, Cancellable<Void>) {
        let channel = Channel<ValueAction>.init(buffering: buffering)
        let cancellable = Cancellable<Void> {
            for await outputAction in channel.stream {
                switch outputAction {
                    case let .asynchronousValue(output, resumption):
                        do {
                            try upstreamChannel.tryYield(.value(output, resumption))
                        }
                        catch {
                            channel.finish()
                            resumption.resume(throwing: error)
                        }
                    case let .synchronousValue(output):
                        try await withResumption { resumption in
                            do { try upstreamChannel.tryYield(.value(output, resumption)) }
                            catch {
                                channel.finish()
                                resumption.resume(throwing: error)
                            }
                        }
                }
            }
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
                    catch { fatalError("Could not subscribe") }
                }
            },
            onCancel: {
                channel.finish()
            }
        ) } )
        return (channel, cancellable)
    }

    // subscribe is async bc it must return the Cancellable
    public func subscribe(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        operation: @escaping @Sendable (Publisher<Output>.Result) async throws -> Void
    ) -> Cancellable<Cancellable<Void>> {
        .init { try await self.subscribe(
            function: function,
            file: file,
            line: line,
            operation: operation
        ) }
    }

    public func subscribe(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        operation: @escaping @Sendable (Publisher<Output>.Result) async throws -> Void
    ) async throws -> Cancellable<Void> {
        let id = UInt64.random(in: 0 ..< UInt64.max)
        let first = await Repeater.first(
            function: function,
            file: file,
            line: line,
            id: id,
            dispatch: operation,
            returnChannel: returnChannel
        )
        let compare: UInt64 = try await withResumption({ idResumption in
            do { try subscriptionChannel.tryYield(.subscribe(first.repeater, first.resumption, idResumption)) }
            catch { try? idResumption.tryResume(throwing: SubscriptionError()) }
        })
        guard compare == id else { throw SubscriptionError() }
        return .init(function: function, file: file, line: line) { try await withTaskCancellationHandler(
            operation: { _ = try await first.repeater.cancellable.value },
            onCancel: { try? self.subscriptionChannel.tryYield(.unsubscribe(id)) }
        ) }
    }

    public func send(_ value: Output) throws {
        try valueChannel.tryYield(.synchronousValue(value))
    }

    public func send(_ value: Output) async throws {
        try await withResumption { resumption in
            do {
                try valueChannel.tryYield(.asynchronousValue(value, resumption))
            }
            catch {
                resumption.resume(throwing: BufferError())
            }
        }
    }

    func finish() async {
        valueChannel.finish()
        subscriptionChannel.finish()
        _ = await valueCancellable.result
        _ = await subscriptionCancellable.result
        returnChannel.finish()
        upstreamChannel.finish()
    }

    var result: Result<Void, Swift.Error> {
        get async { await upstreamCancellable.result }
    }
}
