//
//  Merged.swift
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
import Queue

public extension Publisher {
    func merge(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        with upstream2: Publisher<Output>,
        _ otherUpstreams: Publisher<Output>...
    ) -> Publisher<Output> {
        Merged(function: function, file: file, line: line, self, upstream2, otherUpstreams)
    }
}

@Sendable public func Merged<Output: Sendable, S: Sequence>(
    function: StaticString = #function,
    file: StaticString = #file,
    line: UInt = #line,
    _ upstream1: Publisher<Output>,
    _ upstream2: Publisher<Output>,
    _ otherUpstreams: S
) -> Publisher<Output> where S.Element == Publisher<Output>, S: Sendable {
    merge(function: function, file: file, line: line, publishers: upstream1, upstream2, otherUpstreams)
}

@Sendable public func Merged<Output: Sendable>(
    function: StaticString = #function,
    file: StaticString = #file,
    line: UInt = #line,
    _ upstream1: Publisher<Output>,
    _ upstream2: Publisher<Output>,
    _ otherUpstreams: Publisher<Output>...
) -> Publisher<Output> {
    merge(function: function, file: file, line: line, publishers: upstream1, upstream2, otherUpstreams)
}

@Sendable public func merge<Output: Sendable>(
    function: StaticString = #function,
    file: StaticString = #file,
    line: UInt = #line,
    publishers upstream1: Publisher<Output>,
    _ upstream2: Publisher<Output>,
    _ otherUpstreams: Publisher<Output>...
) -> Publisher<Output> {
    merge(function: function, file: file, line: line, publishers: upstream1, upstream2, otherUpstreams)
}

@Sendable public func merge<Output: Sendable, S: Sequence>(
    function: StaticString = #function,
    file: StaticString = #file,
    line: UInt = #line,
    publishers upstream1: Publisher<Output>,
    _ upstream2: Publisher<Output>,
    _ otherUpstreams: S
) -> Publisher<Output> where S.Element == Publisher<Output>, S: Sendable {
    .init { resumption, downstream in
        let cancellable = Queue<Merge<Output>.Action>(buffering: .bufferingOldest(2 + otherUpstreams.underestimatedCount))
            .fold(
                function: function,
                file: file,
                line: line,
                onStartup: resumption,
                into: Merge<Output>.folder(
                    publishers: [upstream1, upstream2] + otherUpstreams,
                    downstream: downstream
                )
            )
            .cancellable
        return .init(function: function, file: file, line: line) {
            try await withTaskCancellationHandler(
                operation: {
                    _ = try await cancellable.value
                    return
                },
                onCancel: { try? cancellable.cancel() }
            )
        }
    }
}

public func merge<Output, S: Sequence>(
    function: StaticString = #function,
    file: StaticString = #file,
    line: UInt = #line,
    publishers: S
) -> Publisher<Output> where S.Element == Publisher<Output> {
    let array = Array(publishers)
    switch array.count {
        case 1:
            return array[0]
        case 2:
            return Merged(function: function, file: file, line: line, array[0], array[1])
        case 3... :
            return Merged(function: function, file: file, line: line, array[0], array[1], array[2...])
        default:
            return Publisher<Output>.init(function: function, file: file, line: line)
    }
}
