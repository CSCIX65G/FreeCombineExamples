//
//  Unfolded.swift
//
//
//  Created by Van Simmons on 5/18/22.
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

extension Sequence {
    public var asyncPublisher: Publisher<Element> {
        UnfoldedSequence(self)
    }
    
    public func asyncPublisher(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line
    ) -> Publisher<Element> {
        UnfoldedSequence(function: function, file: file, line: line, self)
    }
}

public func UnfoldedSequence<S: Sequence>(
    function: StaticString = #function,
    file: StaticString = #file,
    line: UInt = #line,
    _ sequence: S
) -> Publisher<S.Element> where S: Sendable {
    .init(function: function, file: file, line: line, sequence)
}

extension Publisher {
    public init<S: Sequence>(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        _ sequence: S
    ) where S.Element == Output, S: Sendable {
        self = .init { resumption, downstream in
            .init(function: function, file: file, line: line) {
                try resumption.resume()
                for a in sequence {
                    guard !Task.isCancelled else {
                        return try await handleCancellation(of: downstream)
                    }
                    try await downstream(.value(a))
                }
                return try await downstream(.completion(.finished))
            }
        }
    }
}

public func Unfolded<Output>(
    function: StaticString = #function,
    file: StaticString = #file,
    line: UInt = #line,
    _ generator: @Sendable @escaping () async throws -> Output?
) -> Publisher<Output> {
    .init(function: function, file: file, line: line, generator)
}

extension Publisher {
    public init(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        _ generator: @Sendable @escaping () async throws -> Output?
    ) {
        self = .init { resumption, downstream in
            .init(function: function, file: file, line: line) {
                try resumption.resume()
                while let a = try await generator() {
                    guard !Task.isCancelled else {
                        return try await handleCancellation(of: downstream)
                    }
                    try await downstream(.value(a))
                }
                return try await downstream(.completion(.finished))
            }
        }
    }
}
