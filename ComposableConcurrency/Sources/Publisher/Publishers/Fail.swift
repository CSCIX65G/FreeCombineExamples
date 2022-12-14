//
//  Fail.swift
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
public func Fail<Output>(
    function: StaticString = #function,
    file: StaticString = #file,
    line: UInt = #line,
    _ t: Output.Type = Output.self,
    _ e: Swift.Error
) -> Publisher<Output> {
    .init(function: function, file: file, line: line, t, e)
}

public extension Publisher {
    init(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        _: Output.Type = Output.self,
        _ error: Swift.Error
    ) {
        self = .init { resumption, downstream in
            .init(function: function, file: file, line: line) {
                try await downstream(.completion(.failure(error)))
            }
        }
    }
}
