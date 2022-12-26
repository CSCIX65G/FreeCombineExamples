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
import Atomics
import Core
import Future

public class Connectable<Output> {
    private let function: StaticString
    private let file: StaticString
    private let line: UInt

    private let ownsSubject: Bool
    private let autoconnect: Bool
    private let atomicIsComplete: ManagedAtomic<Bool> = .init(false)
    private let promise: Promise<Void>

    private let downstreamSubject: Subject<Output>

    private(set) var connector: Cancellable<Void>! = .none
    private(set) var upstreamCancellable: Cancellable<Void>! = .none

    public init(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        upstream: Publisher<Output>,
        autoconnect: Bool = false,
        buffering: AsyncStream<Output>.Continuation.BufferingPolicy = .bufferingOldest(1)
    ) async {
        self.function = function
        self.file = file
        self.line = line
        let localPromise: Promise<Void> = await .init()

        self.autoconnect = autoconnect
        self.ownsSubject = true
        self.downstreamSubject = PassthroughSubject(function: function, file: file, line: line, buffering: buffering)
        self.promise = localPromise
        self.connector = .init {
            do { try await localPromise.value }
            catch {
                try? self.downstreamSubject.cancel()
                throw error
            }
            self.upstreamCancellable = await upstream.sink(function: function, file: file, line: line, self.sink)
        }
    }

    public init(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        upstream: Publisher<Output>,
        subject: Subject<Output>,
        ownsSubject: Bool = false,
        autoconnect: Bool = false
    ) async {
        self.function = function
        self.file = file
        self.line = line
        let localPromise: Promise<Void> = await .init()

        self.downstreamSubject = subject
        self.ownsSubject = ownsSubject
        self.autoconnect = autoconnect
        self.promise = localPromise
        self.connector = .init {
            do {
                try await localPromise.value
            } catch {
                if ownsSubject { try? subject.cancel() }
                throw error
            }
            self.upstreamCancellable = await upstream.sink(function: function, file: file, line: line, self.sink)
        }
    }

    public var result: AsyncResult<Void, Error> {
        get async {
            if ownsSubject { _ = await downstreamSubject.result  }
            _ = await connector.result
            return await upstreamCancellable.result
        }
    }

    @Sendable func sink(_ result: Publisher<Output>.Result) async throws -> Void {
        switch result {
            case let .value(value):
                try await downstreamSubject.send(value)
            case .completion:
                await complete(result)
        }
    }

    public func asyncPublisher(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line
    ) -> Publisher<Output> {
        .init { resumption, downstream in
            Cancellable<Cancellable<Void>>(function: function, file: file, line: line) {
                defer { resumption.resume() }
                guard !self.isComplete else {
                    return .init {
                        try await downstream(.completion(.failure(ConnectableCompletionError())))
                    }
                }
                let downstreamCancellable = await self.downstreamSubject
                    .asyncPublisher()
                    .sink(downstream)

                if self.autoconnect {
                    try? await self.connect(function: function, file: file, line: line)
                }
                return downstreamCancellable
            }.join()
        }
    }

    var isComplete: Bool {
        get { atomicIsComplete.load(ordering: .relaxed) }
    }

    func complete(_ result: Publisher<Output>.Result) async {
        let (success, _) = atomicIsComplete.compareExchange(
            expected: false,
            desired: true,
            ordering: .sequentiallyConsistent
        )
        guard success else { return }
        if ownsSubject {
            try? await downstreamSubject.send(result)
            _ = await downstreamSubject.result
        }
    }

    func connect(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line
    ) async throws -> Void {
        try promise.succeed()
        _ = await connector.result
    }

    func cancel() throws -> Void {
        try promise.fail(CancellationError())
    }
}
