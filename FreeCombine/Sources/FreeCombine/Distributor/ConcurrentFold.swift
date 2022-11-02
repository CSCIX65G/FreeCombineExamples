//
//  ParallelFold.swift
//  
//
//  Created by Van Simmons on 10/30/22.
//

public struct ConcurrentFold<Arg, Return, Folded> {
    public static func processValue(
        invocations: inout [ObjectIdentifier: ConcurrentFunc<Arg, Return>.Invocation],
        arg: Arg,
        channel: Channel<ConcurrentFunc<Arg, Return>.Next>
    ) async -> Folded where Folded == Void {
        var iterator = channel.stream.makeAsyncIterator()
        invocations.forEach { _, invocation in invocation(arg) }
        for _ in 0 ..< invocations.count {
            guard let next = await iterator.next() else { fatalError("Invalid stream") }
            let id = next.id
            guard let invocation = invocations[id] else { fatalError("Lost concurrent function") }
            switch next.result {
                case let .failure(error):
                    next.invocation.resumption.resume(throwing: error)
                    _ = await invocation.function.cancellable.result
                    invocations.removeValue(forKey: id)
                    continue
                case .success:
                    invocations[id] = next.invocation
            }
        }
        return
    }


    public static func processTermination(
        invocations: inout [ObjectIdentifier: ConcurrentFunc<Arg, Return>.Invocation],
        completion: Publishers.Completion = .finished
    ) async -> Folded where Folded == Void {
        invocations.forEach { _, invocation in invocation(completion) }
        for (_, invocation) in invocations { _ = await invocation.function.cancellable.result }
        invocations = [:]
        return
    }
}
