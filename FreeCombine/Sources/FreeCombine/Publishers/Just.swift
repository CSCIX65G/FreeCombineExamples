//
//  Just.swift
//
//
//  Created by Van Simmons on 3/15/22.
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
public func Just<Output>(_ a: Output) -> Publisher<Output> {
    .init(a)
}

public extension Publisher {
    init(_ a: Output) {
        self = .init { resumption, downstream in
            .init {
                resumption.resume()
                _ = try await downstream(.value(a))
                return try await downstream(.completion(.finished))
            }
        }
    }
}

public func Just<Output>(_ generator: @escaping () async -> Output) -> Publisher<Output> {
    .init(generator)
}

public extension Publisher {
    init(_ generator: @escaping () async -> Output) {
        self = .init { resumption, downstream in
            .init {
                resumption.resume()
                _ = try await downstream(.value(generator()))
                return try await downstream(.completion(.finished))
            }
        }
    }
}

public func Just<Output>(_ a: Publisher<Output>.Result) -> Publisher<Output> {
    .init(a)
}

public extension Publisher {
    init(_ result: Publisher<Output>.Result) {
        self = .init { resumption, downstream in
            .init {
                resumption.resume()
                _ = try await downstream(result)
                return try await downstream(.completion(.finished))
            }
        }
    }
}

public func Just<Output>(
    _ generator: @escaping () async -> Publisher<Output>.Result
) -> Publisher<Output> {
    .init(generator)
}

public extension Publisher {
    init(
        _ generator: @escaping () async -> Publisher<Output>.Result
    ) {
        self = .init { resumption, downstream in
            .init {
                resumption.resume()
                _ = try await downstream(generator())
                return try await downstream(.completion(.finished))
            }
        }
    }
}
