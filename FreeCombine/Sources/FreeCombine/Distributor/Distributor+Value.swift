//
//  Distributor+Value.swift
//  
//
//  Created by Van Simmons on 11/1/22.
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
        mainChannel: Queue<DistributionAction>
    ) -> AsyncFolder<ValueState, ValueAction> {
        .init(
            initializer: { _ in .init() },
            reducer: { state, action in
                guard !state.isFinished else { return .none }
                switch action {
                    case let .asyncValue(output):
                        try await pause { resumption in
                            do { try mainChannel.tryYield(.value(output, resumption)) }
                            catch { state.isFinished = true; resumption.resume(throwing: error) }
                        }
                    case let .syncValue(output, resumption):
                        do { try mainChannel.tryYield(.value(output, resumption)) }
                        catch { state.isFinished = true; resumption.resume(throwing: error) }
                    case let .asyncCompletion(completion):
                        try await pause { resumption in
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
