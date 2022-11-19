//
//  Distributor+Distribution.swift
//  
//
//  Created by Van Simmons on 10/31/22.
//
extension Distributor {
    public struct DistributionState {
        var completion: Publishers.Completion? = .none
        var currentValue: Output? = .none
        var invocations: [ObjectIdentifier : ConcurrentFunc<Output, Void>.Invocation] = [:]
    }

    enum DistributionAction: Sendable {
        case value(Publisher<Output>.Result, Resumption<Void>)
        case subscribe(ConcurrentFunc<Output, Void>.Invocation, Resumption<ObjectIdentifier>)
        case unsubscribe(ObjectIdentifier)
        case cancel(ObjectIdentifier)
        case finish(Publishers.Completion, Resumption<Void>)
    }

    static func reduce(
        action: Distributor<Output>.DistributionAction,
        state: inout Distributor<Output>.DistributionState,
        returnChannel: Channel<ConcurrentFunc<Output, Void>.Next>
    ) async throws -> AsyncFolder<Distributor<Output>.DistributionState, Distributor<Output>.DistributionAction>.Effect {
        switch action {
            case let .finish(completion, resumption):
                state.completion = completion
                resumption.resume()
                switch completion {
                    case .finished: throw AsyncFolder<DistributionState, DistributionAction>.Error.finished
                    case let .failure(error): throw error
                }
            case let .value(value, upstreamResumption):
                if case let .value(output) = value, state.currentValue != nil {
                    state.currentValue = output
                }
                state.invocations = await ConcurrentFunc.batch(
                    invocations: state.invocations,
                    arg: value,
                    channel: returnChannel
                )
                upstreamResumption.resume()
            case let .subscribe(invocation, idResumption):
                var inv = invocation
                guard state.invocations[invocation.function.id] == nil else {
                    fatalError("duplicate key: \(invocation.function.id)")
                }
                if let currentValue = state.currentValue {
                    invocation.resumption.resume(returning: .value(currentValue))
                    var it = returnChannel.stream.makeAsyncIterator()
                    guard let next = await it.next() else {
                        fatalError("premature stream termination")
                    }
                    switch next.result {
                        case let .failure(error): try! idResumption.tryResume(throwing: error)
                        default: inv = next.invocation
                    }
                }
                state.invocations[invocation.function.id] = inv
                do { try idResumption.tryResume(returning: invocation.function.id) }
                catch { fatalError("Unhandled subscription resumption error") }
            case let .cancel(streamId):
                guard let invocation = state.invocations.removeValue(forKey: streamId) else {
                    return .none
                }
                try! invocation.resumption.tryResume(returning: .completion(.failure(CancellationError())))
                _ = await invocation.function.cancellable.result
            case let .unsubscribe(streamId):
                guard let invocation = state.invocations.removeValue(forKey: streamId) else {
                    return .none
                }
                try! invocation.resumption.tryResume(returning: .completion(.finished))
                _ = await invocation.function.cancellable.result
        }
        return .none
    }

    static func dispose(_ action: Distributor<Output>.DistributionAction) {
        switch action {
            case let .finish(completion, resumption):
                resumption.resume(throwing: CompletionError(completion: completion))
            case let .value(_, upstreamResumption):
                upstreamResumption.resume()
            case let .subscribe(_, idResumption):
                idResumption.resume(throwing: CancellationError())
            case .cancel:
                ()
            case .unsubscribe:
                ()
        }
    }

    static func finalize(_ state: inout Distributor<Output>.DistributionState) {
        for (_, invocation) in state.invocations {
            switch state.completion {
                case .finished:
                    invocation.resumption.resume(returning: .completion(.finished))
                case let .failure(error):
                    invocation.resumption.resume(throwing: error)
                case .none: ()
            }
        }
    }

    static func distributionFolder(
        currentValue: Output? = .none,
        returnChannel: Channel<ConcurrentFunc<Output, Void>.Next>
    ) -> AsyncFolder<DistributionState, DistributionAction> {
        .init(
            initializer: {_ in .init(currentValue: currentValue) },
            reducer: { state, action in try await reduce(action: action, state: &state, returnChannel: returnChannel) },
            disposer: { action, completion in dispose(action) },
            finalizer: { state, completion in finalize(&state) }
        )
    }
}
