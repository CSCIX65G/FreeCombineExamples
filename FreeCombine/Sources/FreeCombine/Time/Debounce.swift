//
//  Debounce.swift
//
//
//  Created by Van Simmons on 7/8/22.
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
import Atomics

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
extension Publisher {
    func debounce<C: Clock>(
        clock: C,
        duration: Swift.Duration
    ) -> Self where C.Duration == Swift.Duration {
        .init { resumption, downstream in
            let isDispatchable = ManagedAtomic<ValueRef<DownstreamState>>.init(.init(value: .init()))
            let previousValueTimeout = ValueRef<Cancellable<Void>?>(value: .none)
            let downstreamFolderRef = ValueRef<DownstreamFold?>.init(value: .none)
            let downstreamQueue = Queue<Publisher<Output>.Result>.init(buffering: .unbounded)

            return self(onStartup: resumption) { r in
                let dispatchError = isDispatchable.load(ordering: .sequentiallyConsistent).value.errored
                guard dispatchError == nil else { throw dispatchError! }
                
                if downstreamFolderRef.value == nil, case .value = r {
                    downstreamFolderRef.set(
                        value: await createDownstreamFold(isDispatchable, downstreamQueue, downstream)
                    )
                }

                switch r {
                    case .completion:
                        _ = await previousValueTimeout.value?.result
                        downstreamQueue.continuation.yield(r)
                        downstreamQueue.finish()
                        switch await downstreamFolderRef.value?.result {
                            case .success, .none: return
                            case let .failure(error): throw error
                        }

                    case .value:
                        try? previousValueTimeout.value?.cancel()
                        await previousValueTimeout.set(value: Timeout(clock: clock, after: duration).sink { result in
                            guard case .success = result else { return }
                            downstreamQueue.continuation.yield(r)
                        })
                }
            }
        }
    }
}
