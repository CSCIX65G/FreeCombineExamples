//
//  ConcurrentFold.swift
//  
//
//  Created by Van Simmons on 10/30/22.
//
public struct ConcurrentFold<Arg, Return, Folded> {
    public static func processValue(
        invocations: [ObjectIdentifier: ConcurrentFunc<Arg, Return>.Invocation],
        arg: Arg,
        channel: Channel<ConcurrentFunc<Arg, Return>.Next>
    ) async -> Folded where Folded == [ObjectIdentifier: ConcurrentFunc<Arg, Return>.Invocation] {
        var iterator = channel.stream.makeAsyncIterator()
        var retVal: [ObjectIdentifier: ConcurrentFunc<Arg, Return>.Invocation] = [:]
        invocations.forEach { _, invocation in invocation(arg) }
        for _ in 0 ..< invocations.count {
            guard let next = await iterator.next() else { fatalError("Invalid stream") }
            guard let invocation = invocations[next.id] else { fatalError("Lost concurrent function") }
            switch next.result {
                case let .failure(error):
                    next.invocation.resumption.resume(throwing: error)
                    _ = await invocation.function.cancellable.result
                    continue
                case .success:
                    retVal[next.id] = next.invocation
            }
        }
        return retVal
    }
}
