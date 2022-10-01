//
//  Publisher.swift
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
public struct Publisher<Output: Sendable>: Sendable {
    private let call: @Sendable (Resumption<Void>, @escaping Downstream) -> Cancellable<Demand>

    internal init(
        _ call: @escaping @Sendable (Resumption<Void>, @escaping Downstream) -> Cancellable<Demand>
    ) {
        self.call = call
    }
}

public extension Publisher {
    typealias Demand = Publishers.Demand
    typealias Error = Publishers.Error
    typealias Completion = Publishers.Completion
    typealias Downstream = @Sendable (Publisher<Output>.Result) async throws -> Demand

    enum Result: Sendable {
        case value(Output)
        case completion(Publishers.Completion)

        func get() throws -> Output {
            guard case let .value(value) = self else {
                throw Error.completed
            }
            return value
        }
    }
}

public extension Publisher {
    @discardableResult
    func sink(onStartup: Resumption<Void>, _ downstream: @escaping Downstream) -> Cancellable<Demand> {
        self(onStartup: onStartup, downstream)
    }

    @discardableResult
    func callAsFunction(onStartup: Resumption<Void>, _ downstream: @escaping Downstream) -> Cancellable<Demand> {
        call(onStartup, { result in
            guard !Cancellables.isCancelled else {
                return try await handleCancellation(of: downstream)
            }
            switch result {
                case let .value(value):
                    return try await downstream(.value(value))
                case let .completion(.failure(error)):
                    return try await downstream(.completion(.failure(error)))
                case .completion(.finished):
                    return try await downstream(result)
            }
        } )
    }

    @discardableResult
    func sink(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        _ downstream: @escaping Downstream
    ) async -> Cancellable<Demand> {
        await self(function: function, file: file, line: line, downstream)
    }

    @discardableResult
    func callAsFunction(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        _ downstream: @escaping Downstream
    ) async -> Cancellable<Demand> {
        var cancellable: Cancellable<Demand>!
        let _: Void = try! await withResumption(function: function, file: file, line: line) { resumption in
            cancellable = self(onStartup: resumption, downstream)
        }
        return cancellable
    }
}
