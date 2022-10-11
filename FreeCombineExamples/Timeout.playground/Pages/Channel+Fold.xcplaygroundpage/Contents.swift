//: [Previous](@previous)

import PlaygroundSupport

PlaygroundPage.current.needsIndefiniteExecution = true

@available(iOS 13, *)
public struct Channel<Element: Sendable> {
    let continuation: AsyncStream<Element>.Continuation
    let stream: AsyncStream<Element>

    public init(
        _: Element.Type = Element.self,
        buffering: AsyncStream<Element>.Continuation.BufferingPolicy = .bufferingOldest(1)
    ) {
        var localContinuation: AsyncStream<Element>.Continuation!
        stream = .init(bufferingPolicy: buffering) { localContinuation = $0 }
        continuation = localContinuation
    }

    @discardableResult
    @Sendable func yield(_ value: Element) -> AsyncStream<Element>.Continuation.YieldResult {
        continuation.yield(value)
    }

    @Sendable func finish() {
        continuation.finish()
    }
}

public extension Channel where Element == Void {
    @discardableResult
    @Sendable func yield() -> AsyncStream<Element>.Continuation.YieldResult {
        continuation.yield()
    }
}

public enum AsyncFolders {
    public enum Completion {
        case exited
        case failure(Swift.Error)
        case finished
    }

    public enum Error: Swift.Error {
        case cancelled
        case completed
        case finished
    }
}

@available(iOS 13, *)
public struct AsyncFolder<State, Action> {
    public typealias Completion = AsyncFolders.Completion
    public typealias Error = AsyncFolders.Error

    let initializer: (Channel<Action>) async -> State
    let reducer: (inout State, Action) async throws -> [Effect]
    let effectHandler: (Channel<Action>, State, Action) async throws -> Void
    let disposer: (Action, Completion) async -> Void
    let finalizer: (inout State, Completion) async -> Void

    public init(
        initializer: @escaping (Channel<Action>) async -> State,
        reducer: @escaping (inout State, Action) async throws -> [Effect],
        effectHandler: @escaping (Channel<Action>, State, Action) async throws -> Void = { _, _, _ in },
        disposer: @escaping (Action, Completion) async -> Void = { _, _ in },
        finalizer: @escaping (inout State, Completion) async -> Void = { _, _ in }
    ) {
        self.initializer = initializer
        self.reducer = reducer
        self.effectHandler = effectHandler
        self.disposer = disposer
        self.finalizer = finalizer
    }
}

extension AsyncFolder {
    public enum Effect {
        case none
        case completion(Completion)
    }

    func initialize(channel: Channel<Action>) async -> State {
        await initializer(channel)
    }

    func reduce(state: inout State, action: Action) async throws -> [Effect] {
        try await reducer(&state, action)
    }

    func dispose(
        channel: Channel<Action>,
        error: Swift.Error
    ) async -> Void {
        channel.finish()
        for await action in channel.stream {
            switch error {
                case Error.completed:
                    await disposer(action, .finished); continue
                case Error.cancelled:
                    await disposer(action, .failure(Error.cancelled)); continue
                default:
                    await disposer(action, .failure(error)); continue
            }
        }
    }

    func handle(
        effects: [Effect],
        channel: Channel<Action>,
        state: State,
        action: Action
    ) async throws -> Void {
        for effect in effects {
            switch effect {
                case .none: ()
                case .completion(.exited): throw Error.completed
                case .completion(let .failure(error)): throw error
                case .completion(.finished): throw Error.finished
            }
        }
    }

    func finalize(
        state: inout State,
        error: Swift.Error
    ) async throws -> Void {
        guard let completion = error as? Error else {
            await finalizer(&state, .failure(error))
            throw error
        }
        switch completion {
            case .cancelled:
                await finalizer(&state, .failure(Error.cancelled))
                throw completion
            case .finished:
                await finalizer(&state, .finished)
            case .completed:
                await finalizer(&state, .exited)
        }
    }

    func finalize(_ state: inout State, _ completion: Completion) async -> Void {
        await finalizer(&state, completion)
    }
}

@available(iOS 13, *)
public final class AsyncFold<State, Action: Sendable> {
    public typealias Error = AsyncFolders.Error

    let channel: Channel<Action>
    public let cancellable: Cancellable<State>

    init(channel: Channel<Action>, cancellable: Cancellable<State>) {
        self.channel = channel
        self.cancellable = cancellable
    }

    public var value: State {
        get async throws { try await cancellable.value }
    }

    var result: Result<State, Swift.Error> {
        get async { await cancellable.result }
    }

    @Sendable func send(_ element: Action) -> AsyncStream<Action>.Continuation.YieldResult {
        channel.yield(element)
    }

    @Sendable func finish() {
        channel.finish()
    }

    @Sendable func cancel() throws {
        try cancellable.cancel()
    }
}

extension AsyncFold {
    static func fold(
        channel: Channel<Action>,
        folder: AsyncFolder<State, Action>
    ) async -> Self {
        var fold: Self!
        try! await withResumption { startup in
            fold = .init(
                onStartup: startup,
                channel: channel,
                folder: folder
            )
        }
        return fold
    }

    public convenience init(
        onStartup: Resumption<Void>,
        channel: Channel<Action>,
        folder: AsyncFolder<State, Action>
    ) {
        self.init(
            channel: channel,
            cancellable: .init {
                try await withTaskCancellationHandler(
                    operation: {
                        try await Self.runloop(onStartup: onStartup, channel: channel, folder: folder)
                    },
                    onCancel: channel.finish
                )
            }
        )
    }

    private static func runloop(
        onStartup: Resumption<Void>,
        channel: Channel<Action>,
        folder: AsyncFolder<State, Action>
    ) async throws -> State {
        var state = await folder.initialize(channel: channel)
        do {
            onStartup.resume()
            for await action in channel.stream {
                let effects = try await folder.reduce(state: &state, action: action)
                try await folder.handle(
                    effects: effects,
                    channel: channel,
                    state: state,
                    action: action
                )
            }
            await folder.finalize(&state, .finished)
        } catch {
            await folder.dispose(channel: channel, error: error)
            try await folder.finalize(state: &state, error: error)
        }
        return state
    }
}

public extension Channel {
    func fold<State>(
        onStartup: Resumption<Void>,
        into folder: AsyncFolder<State, Element>
    ) -> AsyncFold<State, Element> {
        .init(onStartup: onStartup, channel: self, folder: folder)
    }
}

public extension Channel {
    func fold<State>(
        into folder: AsyncFolder<State, Element>
    ) async -> AsyncFold<State, Element> {
        await AsyncFold<State, Element>.fold(channel: self, folder: folder)
    }
}

PlaygroundPage.current.finishExecution()

//: [Next](@next)
