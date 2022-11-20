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
        var folded: [ObjectIdentifier: ConcurrentFunc<Arg, Return>] = [:]
        downstreams.forEach { _, invocation in try! invocation(resultArg) }
        for _ in 0 ..< downstreams.count {
            guard let next = await iterator.next() else { fatalError("Invalid stream") }
            guard let invocation = downstreams[next.id] else { fatalError("Lost concurrent function") }
            switch next.result {
                case let .failure(error):
                    next.invocation.resumption.resume(throwing: error)
                    _ = await invocation.dispatch.cancellable.result
                    continue
                case .success:
                    folded[next.id] = next.invocation
            }
        }
        return folded
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
            var folded: [ObjectIdentifier: ConcurrentFunc<Arg, Return>.Next] = [:]
            downstreams.forEach { _, invocation in try! invocation(resultArg) }
            for _ in 0 ..< downstreams.count {
                guard let next = await iterator.next() else { fatalError("Invalid stream") }
                folded[next.id] = next
            }
            results = folded
        }

        var successes: Self {
            get async {
                var newResults: [ObjectIdentifier: ConcurrentFunc<Arg, Return>.Next] = [:]
                for (id, next) in results {
                    switch next.result {
                        case let .failure(error):
                            try? next.invocation(error: error)
                            _ = await next.invocation.dispatch.cancellable.result
                            continue
                        case .success:
                            newResults[id] = next
                    }
                }
                return .init(results: newResults)
            }
        }
    }
}
