//
//  Future.swift
//  UsingFreeCombine
//
//  Created by Van Simmons on 9/5/22.
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
/*: Modelled after EventLoopFuture from NIO
 [ELF's should be lock-free](https://github.com/apple/swift-nio/blob/26afcecdc2142f1cd0d9b7f4d25b3a72938c3368/Sources/NIOCore/EventLoopFuture.swift#L379)

 Note that a major difference between ELF and Future is that
 every Future creates a Cancellable as a result of its `sink` call.
 It is the Cancellable that is a reference type while Future is a struct.
 It is the Cancellable that is not allowed to leak.

 We do _not_ implement whenSuccess/whenFailure in the manner of NIO.  Future's `sink`
 call accepts a Result and the consumer is responsible for responding appropriately
 to that.
 */
import Core

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
            guard !Cancellables.isCancelled else {
                return await downstream(.failure(CancellationError()))
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
        let _: Void = try! await pause { resumption in
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
