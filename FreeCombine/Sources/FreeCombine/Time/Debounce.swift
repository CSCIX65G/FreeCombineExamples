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
    private struct DebounceStep {
        let inner: Cancellable<Void>
        let outer: Cancellable<Void>
        let promise: Promise<Void>
    }

    func debounce<C: Clock>(
        clock: C,
        duration: Swift.Duration
    ) -> Self where C.Duration == Swift.Duration {
        .init { resumption, downstream in
            let timeouts: ValueRef<DebounceStep?> = .init(value: .none)

            return self(onStartup: resumption) { r in
                if timeouts.value != nil {
                    do {
                        try timeouts.value!.inner.cancel()
                    } catch { }
                    _ = try await timeouts.value!.outer.value
                }

                switch r {
                    case .completion:
                        return try await downstream(r)
                    case .value:
                        let promise = await Promise<Void>()
                        let newInner = await Timeout(clock: clock, after: duration).sink { result in
                            switch result {
                                case .success: try? promise.succeed()
                                case let .failure(error): try? promise.fail(error)
                            }
                        }
                        let newOuter = Cancellable<Void> {
                            guard case .success = await promise.result else { return }
                            try await downstream(r)
                        }
                        timeouts.set(value: .init(inner: newInner, outer: newOuter, promise: promise))
                }
            }
        }
    }
}
