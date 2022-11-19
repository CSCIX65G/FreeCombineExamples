//
//  ConcurrentFunc+Fold.swift
//  
//
//  Created by Van Simmons on 11/3/22.
//

extension ConcurrentFunc {
    public static func batch(
        invocations: [ObjectIdentifier: ConcurrentFunc<Arg, Return>.Invocation],
        resultArg: Publisher<Arg>.Result,
        channel: Channel<ConcurrentFunc<Arg, Return>.Next>
    ) async -> [ObjectIdentifier: ConcurrentFunc<Arg, Return>.Invocation] {
        var iterator = channel.stream.makeAsyncIterator()
        var folded: [ObjectIdentifier: ConcurrentFunc<Arg, Return>.Invocation] = [:]
        invocations.forEach { _, invocation in invocation(resultArg: resultArg) }
        for _ in 0 ..< invocations.count {
            guard let next = await iterator.next() else { fatalError("Invalid stream") }
            guard let invocation = invocations[next.id] else { fatalError("Lost concurrent function") }
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
}
