//
//  ConcurrentFunc+Fold.swift
//  
//
//  Created by Van Simmons on 11/3/22.
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

public extension ConcurrentFunc {
    static func batch(
        downstreams: [ObjectIdentifier: ConcurrentFunc<Arg, Return>],
        resultArg: Publisher<Arg>.Result,
        channel: Queue<ConcurrentFunc<Arg, Return>.Next>
    ) async -> [ObjectIdentifier: ConcurrentFunc<Arg, Return>] {
        var iterator = channel.stream.makeAsyncIterator()
        var invocations: [ObjectIdentifier: ConcurrentFunc<Arg, Return>] = [:]
        downstreams.forEach { _, invocation in try! invocation(returnChannel: channel, resultArg) }
        for _ in 0 ..< downstreams.count {
            guard let next = await iterator.next() else { fatalError("Invalid stream") }
            guard let invocation = downstreams[next.id] else { fatalError("Lost concurrent function") }
            switch next.result {
                case let .failure(error):
                    try! next.concurrentFunc.resumption.resume(throwing: error)
                    _ = await invocation.dispatch.cancellable.result
                    continue
                case .success:
                    invocations[next.id] = next.concurrentFunc
            }
        }
        return invocations
    }

    struct Batch {
        let results: [ObjectIdentifier: ConcurrentFunc<Arg, Return>.Next]

        private init(results: [ObjectIdentifier: ConcurrentFunc<Arg, Return>.Next]) {
            self.results = results
        }

        public init(
            downstreams: [ObjectIdentifier: ConcurrentFunc<Arg, Return>],
            resultArg: Publisher<Arg>.Result,
            channel: Queue<ConcurrentFunc<Arg, Return>.Next>
        ) async {
            var iterator = channel.stream.makeAsyncIterator()
            var nexts: [ObjectIdentifier: ConcurrentFunc<Arg, Return>.Next] = [:]
            downstreams.forEach { _, invocation in try! invocation(returnChannel: channel, resultArg) }
            for _ in 0 ..< downstreams.count {
                guard let next = await iterator.next() else { fatalError("Invalid stream") }
                nexts[next.id] = next
            }
            results = nexts
        }

        func successes(
            channel: Queue<ConcurrentFunc<Arg, Return>.Next>
        ) async -> [ObjectIdentifier: ConcurrentFunc<Arg, Return>.Next] {
            var newResults: [ObjectIdentifier: ConcurrentFunc<Arg, Return>.Next] = [:]
            for (id, next) in results {
                guard let invocation = results[id]?.concurrentFunc else { fatalError("Lost concurrent function") }
                switch next.result {
                    case let .failure(error):
                        try? invocation(returnChannel: channel, error: error)
                        _ = await next.concurrentFunc.result
                        continue
                    case .success:
                        newResults[id] = next
                }
            }
            return newResults
        }
    }
}
