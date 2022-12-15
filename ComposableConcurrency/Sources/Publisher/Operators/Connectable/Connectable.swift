//
//  Connectable.swift
//  
//
//  Created by Van Simmons on 12/14/22.
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

public class Connectable<Output> {
    fileprivate let upstream: Publisher<Output>
    fileprivate let subject: Subject<Output>
    fileprivate var cancellable: Cancellable<Void>? = .none

    init(
        upstream: Publisher<Output>,
        buffering: AsyncStream<Output>.Continuation.BufferingPolicy = .bufferingOldest(1)
    ) {
        self.upstream = upstream
        self.subject = PassthroughSubject(buffering: buffering)
    }

    var result: AsyncResult<Void, Error> {
        get async { await subject.result }
    }

    var asyncPublisher: Publisher<Output> {
        .init(self)
    }

    func connect() async -> Void {
        cancellable = await self.upstream.sink { result in
            switch result {
                case let .value(value):
                    try await self.subject.send(value)
                case let .completion(.failure(error)):
                    try await self.subject.fail(error)
                case .completion(.finished):
                    try await self.subject.finish()
            }
        }
    }

    func cancel() throws -> Void {
        try cancellable?.cancel()
    }
}

public extension Publisher {
    init(_ connectable: Connectable<Output>) {
        self = .init { resumption, downstream in
            return Cancellable<Cancellable<Void>>.init {
                await connectable.subject.asyncPublisher.sink(downstream)
            }.join()
        }
    }
}
