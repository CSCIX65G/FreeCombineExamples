//
//  Deferred.swift
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
public func Deferred<Element>(
    function: StaticString = #function,
    file: StaticString = #file,
    line: UInt = #line,
    from flattable: Publisher<Element>
) -> Publisher<Element> {
    .init(function: function, file: file, line: line, from: flattable)
}

extension Publisher {
    init(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        from flattable: Publisher<Output>
    ) {
        self = .init { resumption, downstream in
            .init(function: function, file: file, line: line) {
                resumption.resume()
                return try await flattable(downstream).value
            }
        }
    }
}

public func Deferred<Element>(
    function: StaticString = #function,
    file: StaticString = #file,
    line: UInt = #line,
    flattener: @escaping () async -> Publisher<Element>
) -> Publisher<Element> {
    .init(function: function, file: file, line: line, from: flattener)
}

extension Publisher {
    init(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        from flattener: @escaping () async throws -> Publisher<Output>
    ) {
        self = .init { resumption, downstream in
            .init(function: function, file: file, line: line) {
                resumption.resume()
                let p = try await flattener()
                let c = await p(downstream)
                return try await c.value
            }
        }
    }
}
