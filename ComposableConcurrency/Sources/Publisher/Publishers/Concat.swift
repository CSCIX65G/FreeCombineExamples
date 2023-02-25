//
//  Concat.swift
//
//
//  Created by Van Simmons on 5/17/22.
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
public extension Publisher  {
    func concat(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        _ other: Publisher<Output>
    ) -> Publisher<Output> {
        .init(function: function, file: file, line: line, concatenating: [self, other])
    }
}

public func Concat<Output, S: Sequence>(
    function: StaticString = #function,
    file: StaticString = #file,
    line: UInt = #line,
    _ publishers: S
) -> Publisher<Output> where S.Element == Publisher<Output>{
    .init(function: function, file: file, line: line, concatenating: publishers)
}

public extension Publisher {
    init<S: Sequence>(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        concatenating publishers: S
    ) where S.Element: Sendable, S.Element == Publisher<Output>, S: Sendable {
        self = .init { resumption, downstream  in
            let flattenedDownstream = flattener(downstream)
            return .init(function: function, file: file, line: line) {
                resumption.resume()
                for p in publishers {
                    try await p(flattenedDownstream).value
                }
                return try await downstream(.completion(.finished))
            }
        }
    }
}

public func Concat<Element>(
    function: StaticString = #function,
    file: StaticString = #file,
    line: UInt = #line,
    _ publishers: Publisher<Element>...
) -> Publisher<Element> {
    .init(function: function, file: file, line: line, concatenating: publishers)
}

public extension Publisher {
    init(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        concatenating publishers: Publisher<Output>...
    ) {
        self = .init(function: function, file: file, line: line, concatenating: publishers)
    }
}

public func Concat<Element>(
    function: StaticString = #function,
    file: StaticString = #file,
    line: UInt = #line,
    _ publishers: @Sendable @escaping () async -> Publisher<Element>?
) -> Publisher<Element> {
    .init(function: function, file: file, line: line, flattening: publishers)
}

public extension Publisher {
    init(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        flattening: @Sendable @escaping () async -> Publisher<Output>?
    ) {
        self = .init { resumption, downstream  in
            let flattenedDownstream = flattener(downstream)
            return .init(function: function, file: file, line: line) {
                resumption.resume()
                while let p = await flattening() { try await p(flattenedDownstream).value }
                return try await downstream(.completion(.finished))
            }
        }
    }
}
