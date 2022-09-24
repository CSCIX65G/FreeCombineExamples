//
//  Channel+Publisher.swift
//
//
//  Created by Van Simmons on 7/1/22.
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
public extension Channel {
    typealias Demand = Publishers.Demand
    func consume<Upstream>(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        publisher: Publisher<Upstream>
    ) async -> Cancellable<Demand> where Element == (Publisher<Upstream>.Result, Resumption<Demand>) {
        await consume(function: function, file: file, line: line, publisher: publisher, using: { ($0, $1) })
    }

    func consume<Upstream>(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        publisher: Publisher<Upstream>,
        using action: @escaping (Publisher<Upstream>.Result, Resumption<Demand>) -> Element
    ) async -> Cancellable<Demand>  {
        await publisher { upstreamValue in
            try await withResumption(function: function, file: file, line: line) { resumption in
                if Task.isCancelled {
                    resumption.resume(throwing: Error.cancelled)
                    return
                }
                switch self.yield(action(upstreamValue, resumption)) {
                    case .enqueued:
                        ()
                    case .dropped:
                        resumption.resume(throwing: Error.enqueueError)
                    case .terminated:
                        resumption.resume(throwing: Error.cancelled)
                    @unknown default:
                        fatalError("Unhandled resumption value")
                }
            }
        }
    }
}
