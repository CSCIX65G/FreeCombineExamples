//
//  Distributor+Distribution.swift
//  
//
//  Created by Van Simmons on 10/31/22.
//
extension Distributor {
    public struct DistributionState {
        var completion: Publishers.Completion? = .none
        var invocations: [ObjectIdentifier : ConcurrentFunc<Output, Void>.Invocation] = [:]
    }

    enum DistributionAction: Sendable {
        case value(Output, Resumption<Void>)
        case subscribe(ConcurrentFunc<Output, Void>.Invocation, Resumption<ObjectIdentifier>)
        case unsubscribe(ObjectIdentifier)
        case finish(Publishers.Completion, Resumption<Void>)
    }

    static func reduce(
        action: Distributor<Output>.DistributionAction,
        state: inout Distributor<Output>.DistributionState,
        returnChannel: Channel<ConcurrentFunc<Output, Void>.Next>
    ) async throws -> [AsyncFolder<Distributor<Output>.DistributionState, Distributor<Output>.DistributionAction>.Effect] {
        switch action {
            case let .finish(completion, resumption):
                state.completion = completion
                resumption.resume()
                switch completion {
                    case .finished: throw AsyncFolder<DistributionState, DistributionAction>.Error.finished
                    case let .failure(error): throw error
                }
            case let .value(value, upstreamResumption):
                state.invocations = await ConcurrentFunc.fold(
                    invocations: state.invocations,
                    arg: value,
                    channel: returnChannel
                )
                upstreamResumption.resume()
            case let .subscribe(invocation, idResumption):
                guard state.invocations[invocation.function.id] == nil else {
                    fatalError("duplicate key: \(invocation.function.id)")
                }
                state.invocations[invocation.function.id] = invocation
                do { try idResumption.tryResume(returning: invocation.function.id) }
                catch { fatalError("Unhandled subscription resumption") }
            case let .unsubscribe(streamId):
                guard let invocation = state.invocations.removeValue(forKey: streamId) else { return [] }
                try! invocation.resumption.tryResume(throwing: CancellationError())
                _ = await invocation.function.cancellable.result
        }
        return []
    }

    static func dispose(_ action: Distributor<Output>.DistributionAction) {
        switch action {
            case let .finish(completion, resumption):
                resumption.resume(throwing: CompletionError(completion: completion))
            case let .value(_, upstreamResumption):
                upstreamResumption.resume()
            case let .subscribe(_, idResumption):
                idResumption.resume(throwing: CancellationError())
            case .unsubscribe:
                ()
        }
    }

    static func finalize(_ state: Distributor<Output>.DistributionState) {
        for (_, invocation) in state.invocations {
            switch state.completion {
                case .finished: invocation.resumption.resume(returning: .completion(.finished))
                case let .failure(error): invocation.resumption.resume(throwing: error)
                case .none: ()
            }
        }
    }

    static func distributionFolder(
        returnChannel: Channel<ConcurrentFunc<Output, Void>.Next>
    ) -> AsyncFolder<DistributionState, DistributionAction> {
        .init(
            initializer: {_ in .init() },
            reducer: { state, action in try await reduce(action: action, state: &state, returnChannel: returnChannel) },
            disposer: { action, completion in dispose(action) },
            finalizer: { state, completion in finalize(state) }
        )
    }
}
