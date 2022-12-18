//
//  Multicast.swift
//
//
//  Created by Van Simmons on 6/26/22.
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
public extension Publisher {
    func multicast(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        _ subject: Subject<Output>
    ) async -> Connectable<Output> {
        await .init(upstream: self, subject: subject)
    }

    func multicast(
        _ generator: @escaping () -> Subject<Output>
    ) async -> Connectable<Output> {
        return await multicast(generator())
    }
}
