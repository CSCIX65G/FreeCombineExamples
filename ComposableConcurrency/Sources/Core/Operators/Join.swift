//
//  Join.swift
//  
//
//  Created by Van Simmons on 12/10/22.
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
public extension Cancellable {
    func join<T>() -> Cancellable<T> where Output == Cancellable<T> {
        .init {
            let inner = try await self.value
            guard !Cancellables.isCancelled else {
                try? inner.cancel()
                throw CancellationError()
            }
            let value = try await withTaskCancellationHandler(
                operation: {try await inner.value },
                onCancel: {
                    try? inner.cancel()
                }
            )

            return value
        }
    }
}

extension Uncancellable {
    public func join<T>() -> Uncancellable<T> where Output == Uncancellable<T> {
        .init { await self.value.value }
    }
}
