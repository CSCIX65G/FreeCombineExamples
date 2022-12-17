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
    private(set) var cancellable: Cancellable<Void>? = .none

    init(
        upstream: Publisher<Output>,
        buffering: AsyncStream<Output>.Continuation.BufferingPolicy = .bufferingOldest(1)
    ) {
        self.upstream = upstream
        self.subject = PassthroughSubject(buffering: buffering)
    }

    init(
        upstream: Publisher<Output>,
        subject: Subject<Output>
    ) {
        self.upstream = upstream
        self.subject = subject
    }

    var result: AsyncResult<Void, Error> {
        get async { await subject.result }
    }

    var asyncPublisher: Publisher<Output> {
        .init(connectable: self)
    }

    func publisher(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line
    ) -> Publisher<Output> {
        .init(
            function: function,
            file: file,
            line: line,
            connectable: self
        )
    }

    static func autoconnect(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        publisher: Publisher<Output>
    ) async -> Publisher<Output> {
        let subject: Subject<Output> = PassthroughSubject()
        let connectable: Connectable<Output> = .init(upstream: publisher, subject: subject)
        return .init { resumption, downstream in
            Cancellable<Cancellable<Void>> {
                let cancellable = await subject.asyncPublisher.sink(downstream)
                if connectable.cancellable == nil {
                    await connectable.connect()
                    try? connectable.cancellable?.release()
                }
                resumption.resume()
                return cancellable
            }.join()
        }
    }

    func connect(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line
    ) async -> Void {
        cancellable = await self.upstream.sink(function: function, file: file, line: line) { result in
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
    init(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        connectable: Connectable<Output>
    ) {
        self = .init { resumption, downstream in
            Cancellable<Cancellable<Void>>.init {
                connectable.subject.asyncPublisher.sink(
                    function: function,
                    file: file,
                    line: line,
                    onStartup: resumption,
                    downstream
                )
            }.join()
        }
    }
}
