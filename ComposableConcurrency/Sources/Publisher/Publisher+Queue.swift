//
//  Channel+Publisher.swift
//
//
//  Created by Van Simmons on 7/1/22.
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
import Queue

public extension Queue {
    @Sendable func consume<Upstream>(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        publisher: Publisher<Upstream>
    ) async -> Cancellable<Void> where Element == (Publisher<Upstream>.Result, Resumption<Void>) {
        await consume(function: function, file: file, line: line, publisher: publisher, using: { ($0, $1) })
    }

    @Sendable func consume<Upstream>(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        publisher: Publisher<Upstream>,
        using action: @Sendable @escaping (Publisher<Upstream>.Result, Resumption<Void>) -> Element
    ) async -> Cancellable<Void>  {
        await publisher { upstreamValue in
            try await pause(function: function, file: file, line: line) { resumption in
                guard !Cancellables.isCancelled else {
                    return resumption.resume(throwing: CancellationError())
                }
                do { try self.tryYield(action(upstreamValue, resumption)) }
                catch { resumption.resume(throwing: error) }
            }
        }
    }
}

public extension AsyncStream.Continuation {
    func consume<Upstream>(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        publisher: Publisher<Upstream>
    ) async -> Cancellable<Void> where Element == (Publisher<Upstream>.Result, Resumption<Void>) {
        await consume(function: function, file: file, line: line, publisher: publisher, using: { ($0, $1) })
    }

    func consume<Upstream: Sendable>(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        publisher: Publisher<Upstream>,
        using action: @Sendable @escaping (Publisher<Upstream>.Result, Resumption<Void>) -> Element
    ) async -> Cancellable<Void> where Element: Sendable {
        await publisher { upstreamValue in
            try await pause(function: function, file: file, line: line) { resumption in
                guard !Cancellables.isCancelled else {
                    return resumption.resume(throwing: CancellationError())
                }
                do { try self.tryYield(action(upstreamValue, resumption)) }
                catch { resumption.resume(throwing: error) }
            }
        }
    }
}
