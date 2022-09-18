//
//  Future.swift
//  UsingFreeCombine
//
//  Created by Van Simmons on 9/5/22.
//

/*: Modelled after EventLoopFuture from NIO
 [ELF's should be lock-free](https://github.com/apple/swift-nio/blob/26afcecdc2142f1cd0d9b7f4d25b3a72938c3368/Sources/NIOCore/EventLoopFuture.swift#L379)

 Note that a major difference between ELF and Future is that
 every Future creates a Cancellable as a result of it's `sink` call.
 It is the Cancellable that is a reference type while Future is a struct.
 It is the Cancellable that is not allowed to leak.

 We do _not_ implement whenSuccess/whenFailure in the manner of NIO.  Future's `sink`
 call accepts a Result and the consumer is responsible for responding appropriately
 to that.
 */
public struct Future<Output: Sendable>: Sendable {
    private let call: @Sendable (
        Resumption<Void>,
        @escaping @Sendable (Result<Output, Swift.Error>) async -> Void
    ) -> Cancellable<Void>

    internal init(
        _ call: @escaping @Sendable (
            Resumption<Void>,
            @escaping @Sendable (Result<Output, Swift.Error>) async -> Void
        ) -> Cancellable<Void>
    ) {
        self.call = call
    }
}

extension Future {
    @discardableResult
    func callAsFunction(
        onStartup: Resumption<Void>,
        _ downstream: @escaping @Sendable (Result<Output, Swift.Error>) async -> Void
    ) -> Cancellable<Void> {
        call(onStartup, { result in
            guard !Task.isCancelled else {
                return await downstream(.failure(Cancellables.Error.cancelled))
            }
            return await downstream(result)
        } )
    }

    @discardableResult
    func sink(
        onStartup: Resumption<Void>,
        _ downstream: @escaping @Sendable (Result<Output, Swift.Error>) async -> Void
    ) -> Cancellable<Void> {
        self(onStartup: onStartup, downstream)
    }

    @discardableResult
    func callAsFunction(
        _ downstream: @escaping @Sendable (Result<Output, Swift.Error>) async -> Void
    ) async -> Cancellable<Void> {
        var cancellable: Cancellable<Void>!
        let _: Void = try! await withResumption { resumption in
            cancellable = self(onStartup: resumption, downstream)
        }
        return cancellable
    }

    @discardableResult
    func sink(
        _ downstream: @escaping @Sendable (Result<Output, Swift.Error>) async -> Void
    ) async -> Cancellable<Void> {
        await self(downstream)
    }
}
