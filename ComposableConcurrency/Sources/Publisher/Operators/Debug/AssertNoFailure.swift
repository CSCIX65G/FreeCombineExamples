//
//  AssertNoFailure.swift
//
//
//  Created by Van Simmons on 6/7/22.
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
    func assertNoFailure(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        _ prefix: String = ""
    ) -> Self {
        .init { resumption, downstream in
            self(onStartup: resumption) { r in
                guard !Task.isCancelled else {
                    return try await handleCancellation(of: downstream)
                }
                if case let .completion(.failure(error)) = r{
                    assertionFailure("\(prefix) \(file)@\(line): \(error)")
                }
                return try await downstream(r)
            }
        }
    }
}
