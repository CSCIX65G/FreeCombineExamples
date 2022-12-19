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
    func join<T>(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line
    ) -> Cancellable<T> where Output == Cancellable<T> {
        .init(function: function, file: file, line: line) {
            let inner = try await self.value
            guard !Cancellables.isCancelled else {
                try? inner.cancel()
                throw CancellationError()
            }
            let value = try await withTaskCancellationHandler(
                operation: { try await inner.value },
                onCancel: {
                    try? inner.cancel()
                }
            )
            return value
        }
    }
}

extension Uncancellable {
    public func join<T>(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line
    ) -> Uncancellable<T> where Output == Uncancellable<T> {
        .init(function: function, file: file, line: line) { await self.value.value }
    }
}

extension UnfailingResumption {
    public func join<T>(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        effect: @Sendable @escaping (T) async -> Void = { _ in }
    ) -> UnfailingResumption<T> where Output == UnfailingResumption<T> {
        let u: MutableBox<UnfailingResumption<T>?> = .init(value: .none)
        _ = try? Uncancellable<Void>(function: function, file: file, line: line) {
            await effect(unfailingPause { r in
                u.set(value: r)
                self.resume(returning: r)
            })
        }.release()
        return u.value!
    }
}

extension Resumption {
    public func join<T>(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        effect: @Sendable @escaping (T) async throws -> Void = { _ in }
    ) -> Resumption<T> where Output == Resumption<T> {
        let u: MutableBox<Resumption<T>?> = .init(value: .none)
        _ = try? Cancellable<Void>(function: function, file: file, line: line) {
            try await effect(pause { r in
                u.set(value: r)
                self.resume(returning: r)
            })
        }.release()
        return u.value!
    }
}
