//
//  Reduce.swift
//
//
//  Created by Van Simmons on 5/19/22.
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
import Core
import SendableAtomics

public extension Publisher {
    func reduce<T: Sendable>(
        _ initialValue: T,
        _ transform: @Sendable @escaping (T, Output) async -> T
    ) -> Publisher<T> {
        return .init { resumption, downstream in
            let currentValue: MutableBox<T> = MutableBox(value: initialValue)
            return self(onStartup: resumption) { r in
                guard !Task.isCancelled else {
                    return try await handleCancellation(of: downstream)
                }
                switch r {
                    case .value(let a):
                        await currentValue.set(value: transform(currentValue.value, a))
                        return
                    case let .completion(value):
                        _ = try await downstream(.value(currentValue.value))
                        return try await downstream(.completion(value))
                }
            }
        }
    }
}
