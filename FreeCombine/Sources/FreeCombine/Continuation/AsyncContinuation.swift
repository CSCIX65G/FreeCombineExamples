//
//  AsyncContinuations.swift
//  
//
//  Created by Van Simmons on 9/13/22.
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

public struct AsyncContinuation<Output: Sendable, Return>: Sendable {
    private let call: @Sendable (
        Resumption<Void>,
        @escaping @Sendable (Output) async throws -> Return
    ) -> Cancellable<Return>

    init(
        _ call: @escaping @Sendable (
            Resumption<Void>,
            @escaping @Sendable (Output) async throws -> Return
        ) -> Cancellable<Return>
    ) {
        self.call = call
    }
}

extension AsyncContinuation {
    @discardableResult
    func callAsFunction(
        onStartup: Resumption<Void>,
        _ downstream: @escaping @Sendable (Output) async throws -> Return
    ) -> Cancellable<Return> {
        call(onStartup) { result in
            try Cancellables.checkCancellation()
            return try await downstream(result)
        }
    }

    @discardableResult
    func sink(
        onStartup: Resumption<Void>,
        _ downstream: @escaping @Sendable (Output) async throws -> Return
    ) -> Cancellable<Return> {
        self(onStartup: onStartup, downstream)
    }

    @discardableResult
    func callAsFunction(
        _ downstream: @escaping @Sendable (Output) async throws -> Return
    ) async -> Cancellable<Return> {
        var cancellable: Cancellable<Return>!
        let _: Void = try! await pause { resumption in
            cancellable = self(onStartup: resumption, downstream)
        }
        return cancellable
    }

    @discardableResult
    func sink(
        _ downstream: @escaping @Sendable (Output) async throws -> Return
    ) async -> Cancellable<Return> {
        await self(downstream)
    }
}
