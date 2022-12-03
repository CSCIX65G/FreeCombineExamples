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
            let downstreamIsSendable = ManagedAtomic<Bool>.init(true)
            let timeouts = ValueRef<Cancellable<Void>?>(value: .none)
            let foldRef = ValueRef<TimerFold?>.init(value: .none)
            let queue = Queue<Publisher<Output>.Result>.init(buffering: .unbounded)

            return self(onStartup: resumption) { r in
                guard downstreamIsSendable.load(ordering: .sequentiallyConsistent) else {
                    _ = try await foldRef.value?.value
                    return
                }

                if foldRef.value == nil, case .value = r {
                    foldRef.set(value: await createTimerFold(
                        downstreamIsSendable: downstreamIsSendable,
                        queue: queue,
                        downstream: downstream
                    ) )
                }

                switch r {
                    case .completion:
                        _ = await timeouts.value?.result
                        queue.finish()
                        switch await foldRef.value?.result {
                            case .success, .none: return try await downstream(r)
                            case let .failure(error): throw error
                        }

                    case .value:
                        try? timeouts.value?.cancel()
                        await timeouts.set(value: Timeout(clock: clock, after: duration).sink { result in
                            switch result {
                                case .success:  queue.continuation.yield(r)
                                case .failure: ()
                            }
                        })
                }
            }
        }
    }
}
