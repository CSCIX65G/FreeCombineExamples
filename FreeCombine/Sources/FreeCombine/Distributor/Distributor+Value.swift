//
//  Distributor+Value.swift
//  
//
//  Created by Van Simmons on 11/1/22.
//

extension Distributor {
    struct ValueState: Sendable {
        var isFinished = false
    }

    enum ValueAction: Sendable {
        case asyncValue(Publisher<Output>.Result)
        case syncValue(Publisher<Output>.Result, Resumption<Void>)
        case asyncCompletion(Publishers.Completion)
        case syncCompletion(Publishers.Completion, Resumption<Void>)
    }

    static func valueFolder(
        mainChannel: Channel<DistributionAction>
    ) -> AsyncFolder<ValueState, ValueAction> {
        .init(
            initializer: { _ in .init() },
            reducer: { state, action in
                guard !state.isFinished else { return .none }
                switch action {
                    case let .asyncValue(output):
                        try await withResumption { resumption in
                            do { try mainChannel.tryYield(.value(output, resumption)) }
                            catch { state.isFinished = true; resumption.resume(throwing: error) }
                        }
                    case let .syncValue(output, resumption):
                        do { try mainChannel.tryYield(.value(output, resumption)) }
                        catch { state.isFinished = true; resumption.resume(throwing: error) }
                    case let .asyncCompletion(completion):
                        try await withResumption { resumption in
                            do { try mainChannel.tryYield(.finish(completion, resumption)) }
                            catch { resumption.resume(throwing: error) }
                        }
                        throw CompletionError(completion: completion)
                    case let .syncCompletion(completion, resumption):
                        do { try mainChannel.tryYield(.finish(completion, resumption)) }
                        catch { resumption.resume(throwing: error) }
                        throw CompletionError(completion: completion)
                }
                return .none
            }
        )
    }
}
