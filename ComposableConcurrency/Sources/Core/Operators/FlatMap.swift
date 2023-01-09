//
//  FlatMap.swift
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
import Foundation

public extension Cancellable {
    func flatMap<T>(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        _ transform: @escaping (Output) async -> Cancellable<T>
    ) -> Cancellable<T> {
        map(transform).join(function: function, file: file, line: line)
    }
}

extension Uncancellable {
    public func flatMap<T>(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        _ transform: @escaping (Output) async -> Uncancellable<T>
    ) -> Uncancellable<T> {
        map(transform).join(function: function, file: file, line: line)
    }
}
