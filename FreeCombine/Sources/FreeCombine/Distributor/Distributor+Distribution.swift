//
//  Distributor+Distribution.swift
//  
//
//  Created by Van Simmons on 10/31/22.
//
//  Copyright 2022, ComputeCycles, LLC
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//
extension Distributor {
    public struct DistributionState {
        var completion: Publishers.Completion? = .none
        var currentValue: Output? = .none
        var invocations: [ObjectIdentifier : ConcurrentFunc<Output, Void>] = [:]
    }

    enum DistributionAction: Sendable {
        case value(Publisher<Output>.Result, Resumption<Void>)
        case subscribe(ConcurrentFunc<Output, Void>, Resumption<ObjectIdentifier>)
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
                throw completion.error
            case let .value(value, upstreamResumption):
                if case let .value(output) = value, state.currentValue != nil {
                    state.currentValue = output
                }
                state.invocations = await ConcurrentFunc.batch(
                    downstreams: state.invocations,
                    resultArg: value,
                    channel: returnChannel
                )
//                .successes.mapValues(\.invocation)
                upstreamResumption.resume()
            case let .subscribe(invocation, idResumption):
                var inv = invocation
                guard state.invocations[invocation.dispatch.id] == nil else {
                    fatalError("duplicate key: \(invocation.dispatch.id)")
                }
                if let currentValue = state.currentValue {
                    try invocation(returnChannel: returnChannel, .value(currentValue))
                    var it = returnChannel.stream.makeAsyncIterator()
                    guard let next = await it.next() else {
                        fatalError("premature stream termination")
                    }
                    switch next.result {
                        case let .failure(error): try! idResumption.tryResume(throwing: error)
                        default: inv = next.concurrentFunc
                    }
                }
                state.invocations[invocation.id] = inv
                do { try idResumption.tryResume(returning: invocation.id) }
                catch { fatalError("Unhandled subscription resumption error") }
            case let .cancel(streamId):
                guard let invocation = state.invocations.removeValue(forKey: streamId) else {
                    return .none
                }
                try invocation(returnChannel: returnChannel, completion: .failure(CancellationError()))
                _ = await invocation.result
            case let .unsubscribe(streamId):
                guard let invocation = state.invocations.removeValue(forKey: streamId) else {
                    return .none
                }
                try! invocation(returnChannel: returnChannel, .completion(.finished))
                _ = await invocation.dispatch.cancellable.result
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

    static func finalize(
        _ state: inout Distributor<Output>.DistributionState,
        returnChannel: Channel<ConcurrentFunc<Output, Void>.Next>
    ) {
        for (_, invocation) in state.invocations {
            switch state.completion {
                case .finished:
                    try? invocation(returnChannel: returnChannel, .completion(.finished))
                case let .failure(error):
                    try? invocation(returnChannel: returnChannel, error: error)
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
            finalizer: { state, completion in finalize(&state, returnChannel: returnChannel) }
        )
    }
}
