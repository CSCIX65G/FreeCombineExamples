//
//  Fold.swift
//
//
//  Created by Van Simmons on 9/5/22.
//
@preconcurrency import Atomics

public class Fold<State, Action> {
    public enum Completion: Equatable {
        case more
        case done
    }
    public enum Error: Swift.Error {
        case alreadyCompleted
    }
    private let done: ManagedAtomic<Bool>
    private let channel: Channel<Action>
    private let cancellable: Cancellable<State>

    required public init(
        initialState: @escaping (Channel<Action>) async -> State,
        channel: Channel<Action>,
        fold: @escaping (inout State, Action) async -> Completion
    ) {
        let atomic = ManagedAtomic<Bool>.init(false)
        self.done = atomic
        self.channel = channel
        self.cancellable = .init {
            var state = await initialState(channel)
            for await action in channel.stream {
                if !Self.isDone(atomic), await fold(&state, action) == .done {
                    Self.set(atomic)
                    channel.finish()
                }
            }
            if Task.isCancelled {
                throw Cancellable<State>.Error.cancelled
            } else {
                return state
            }
        }
    }

    public var canDeallocate: Bool {
        cancellable.isCompleting || cancellable.isCancelled
    }

    deinit {
        guard canDeallocate else {
            assertionFailure("ABORTING DUE TO LEAKED \(type(of: Self.self))")
            try? cancel()
            return
        }
    }
}

extension Fold {
    private static func isDone(_ done: ManagedAtomic<Bool>) -> Bool {
        done.load(ordering: .sequentiallyConsistent)
    }

    private var isDone: Bool {
        done.load(ordering: .sequentiallyConsistent)
    }

    private static func set(_ done: ManagedAtomic<Bool>) {
        done.store(true, ordering: .sequentiallyConsistent)
    }

    private func setIsDone() throws {
        guard done.compareExchange(expected: false, desired: true, ordering: .sequentiallyConsistent).0 else {
            throw Error.alreadyCompleted
        }
    }
}

extension Fold {
    public func cancel() throws {
        cancellable.cancel()
        channel.finish()
        try setIsDone()
    }

    public var isCancelled: Bool {
        cancellable.isCancelled || isDone
    }
}

extension Fold {
    public var result: Result<State, Swift.Error> {
        get async { await cancellable.result }
    }

    public var value: State {
        get async throws { try await cancellable.value }
    }

    public var future: Future<State> {
        .init { resumption, downstream in
            .init {
                resumption.resume()
                await downstream(self.result)
            }
        }
    }
}
