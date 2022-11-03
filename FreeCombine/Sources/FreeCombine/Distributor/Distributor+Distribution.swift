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

    static func distributionFolder(
        returnChannel: Channel<ConcurrentFunc<Output, Void>.Next>
    ) -> AsyncFolder<DistributionState, DistributionAction> {
        .init(
            initializer: {_ in
                .init()
            },
            reducer: { state, action in
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
            },
            disposer: { action, completion in
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
            },
            finalizer: { state, completion in
                for (_, invocation) in state.invocations {
                    switch state.completion {
                        case .finished: invocation.resumption.resume(returning: .completion(.finished))
                        case let .failure(error): invocation.resumption.resume(throwing: error)
                        case .none: ()
                    }
                }
            }
        )
    }
}
