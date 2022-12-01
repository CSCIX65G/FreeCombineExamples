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
            let timeout: ValueRef<Cancellable<Void>?> = .init(value: .none)
            let atomicErrorRef = ManagedAtomic<ValueRef<Error>?>(.none)

            return self(onStartup: resumption) { r in
                if let timeout = timeout.value {
                    try? timeout.cancel()
                }
                if let errorRef = atomicErrorRef.load(ordering: .sequentiallyConsistent) {
                    throw errorRef.value
                }
                switch r {
                    case .completion:
                        return try await downstream(r)
                    case .value:
                        let newTimeout = await Timeout(clock: clock, after: duration).sink { instant in
                            guard case .success = instant else { return }
                            do {
                                if let errorRef = atomicErrorRef.load(ordering: .sequentiallyConsistent) {
                                    throw errorRef.value
                                }
                                try await downstream(r)
                            }
                            catch {
                                guard atomicErrorRef.compareExchange(
                                    expected: .none,
                                    desired: .init(value: error),
                                    ordering: .sequentiallyConsistent
                                ).0 else {
                                    Assertion.assertionFailure(
                                        "Should not be able to set debounce error multiple times"
                                    )
                                    return
                                }
                            }
                        }
                        timeout.set(value: newTimeout)
                }
            }
        }
    }
}
