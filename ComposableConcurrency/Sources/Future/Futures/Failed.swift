//
//  Failed.swift
//
//  Created by Van Simmons on 9/5/22.
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
public func Failed<Output>(
    _ type: Output.Type = Output.self,
    error: Swift.Error
) -> Future<Output> {
    .init(type, error: error)
}

public extension Future {
    init(
        _ type: Output.Type = Output.self,
        error: Swift.Error
    ) {
        self = .init { resumption, downstream in .init {
            try! resumption.resume()
            return await downstream(.failure(error))
        } }
    }
}

public func Fail<Output>(
    _ type: Output.Type = Output.self,
    generator: @Sendable @escaping () async -> Swift.Error
) -> Future<Output> {
    .init(type, generator: generator)
}

public extension Future {
    init(
         _ type: Output.Type = Output.self,
         generator: @Sendable @escaping () async -> Swift.Error
    ) {
        self = .init { resumption, downstream in  .init {
            try! resumption.resume()
            return await downstream(.failure(generator()))
        } }
    }
}
