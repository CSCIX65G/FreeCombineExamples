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
    typealias DebounceFold = AsyncFold<Swift.Result<Void, Swift.Error>, Publisher<Output>.Result>
    func debounce<C: Clock>(
        clock: C,
        duration: Swift.Duration
    ) -> Self where C.Duration == Swift.Duration {
        .init { resumption, downstream in
            let atomic = ManagedAtomic<Bool>.init(true)
            let timeouts = ValueRef<Cancellable<Void>?>(value: .none)
            let foldRef = ValueRef<DebounceFold?>.init(value: .none)
            let queue = Queue<Publisher<Output>.Result>.init(buffering: .unbounded)

            return self(onStartup: resumption) { r in
                if foldRef.value == nil {
                    let f = await queue.fold(into: .init(
                        initializer: { _ in Swift.Result<Void, Swift.Error>.success(()) },
                        reducer: { lastReturn, r in
                            let thisReturn = lastReturn
                            switch thisReturn {
                                case let .failure(error): throw error
                                case .success:
                                    lastReturn = await Swift.Result { try await downstream(r) }
                                    if case .failure = lastReturn {
                                        _ = atomic.exchange(false, ordering: .sequentiallyConsistent)
                                        queue.finish()
                                    }
                            }
                            return .none
                        }
                    ) )
                    foldRef.set(value: f)
                }
                let fold = foldRef.value!

                guard atomic.load(ordering: .sequentiallyConsistent) else {
                    _ = try await fold.value
                    return
                }

                let currentTimeout = timeouts.value
                switch r {
                    case .completion:
                        _ = await currentTimeout?.result
                        queue.finish()
                        switch await fold.result {
                            case .success: return try await downstream(r)
                            case let .failure(error): throw error
                        }

                    case .value:
                        try? currentTimeout?.cancel()
                        let newTimeout = await Timeout(clock: clock, after: duration).sink { result in
                            switch result {
                                case .success:
                                    queue.continuation.yield(r)
                                case .failure:
                                    ()
                            }
                        }
                        timeouts.set(value: newTimeout)
                }
            }
        }
    }
}
