//
//  ConcurrentFunc+Fold.swift
//  
//
//  Created by Van Simmons on 11/3/22.
//

public extension ConcurrentFunc {
    static func batch(
        downstreams: [ObjectIdentifier: ConcurrentFunc<Arg, Return>],
        resultArg: Publisher<Arg>.Result,
        channel: Channel<ConcurrentFunc<Arg, Return>.Next>
    ) async -> [ObjectIdentifier: ConcurrentFunc<Arg, Return>] {
        var iterator = channel.stream.makeAsyncIterator()
        var invocations: [ObjectIdentifier: ConcurrentFunc<Arg, Return>] = [:]
        downstreams.forEach { _, invocation in try! invocation(returnChannel: channel, resultArg) }
        for _ in 0 ..< downstreams.count {
            guard let next = await iterator.next() else { fatalError("Invalid stream") }
            guard let invocation = downstreams[next.id] else { fatalError("Lost concurrent function") }
            switch next.result {
                case let .failure(error):
                    next.concurrentFunc.resumption.resume(throwing: error)
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
            channel: Channel<ConcurrentFunc<Arg, Return>.Next>
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
            channel: Channel<ConcurrentFunc<Arg, Return>.Next>
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
