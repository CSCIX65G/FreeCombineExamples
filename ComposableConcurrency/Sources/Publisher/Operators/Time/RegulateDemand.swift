//
//  DelayEachDemand.swift
//
//
//  Created by Van Simmons on 7/9/22.
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
import Core

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
extension Publisher {
    func regulateDemand<C: Clock>(
        clock: C,
        interval duration: C.Duration
    ) -> Self where C.Duration == Swift.Duration {
        .init { resumption, downstream in
            self(onStartup: resumption) { r in
                let start = clock.now
                try await downstream(r)
                if start.advanced(by: duration) < clock.now {
                    try await clock.sleep(until: start.advanced(by: duration), tolerance: .none)
                }
            }
        }
    }
}