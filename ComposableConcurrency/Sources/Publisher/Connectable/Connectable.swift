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
    private let upstream: Publisher<Output>
    private let subject: Subject<Output>
    private let ownsSubject: Bool
    private let autoconnect: Bool
    private let atomicIsComplete: ManagedAtomic<Bool> = .init(false)
    private let promise: Promise<Void>

    private(set) var cancellable: Cancellable<Void>! = .none
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

        self.upstream = upstream
        self.autoconnect = autoconnect
        self.ownsSubject = true
        self.subject = PassthroughSubject(function: function, file: file, line: line, buffering: buffering)
        self.promise = localPromise
        self.cancellable = .init {
            _ = try await localPromise.value
            self.upstreamCancellable = await self.upstream.sink(function: function, file: file, line: line) { result in
                switch result {
                    case let .value(value):
                        try await self.subject.send(value)
                    case .completion:
                        await self.complete(result)
                }
            }
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

        self.upstream = upstream
        self.subject = subject
        self.ownsSubject = ownsSubject
        self.autoconnect = autoconnect
        self.promise = localPromise
        self.cancellable = .init {
            _ = try await localPromise.value
            self.upstreamCancellable = await self.upstream.sink(function: function, file: file, line: line) { result in
                switch result {
                    case let .value(value):
                        try await self.subject.send(value)
                    case .completion:
                        await self.complete(result)
                }
            }
        }
    }

    public var result: AsyncResult<Void, Error> {
        get async {
            _ = await upstreamCancellable?.result
            if ownsSubject {
                _ = await subject.result
            }
            return await cancellable.result
        }
    }

//    public var asyncPublisher: Publisher<Output> {
//        asyncPublisher()
//    }

    public func asyncPublisher(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line
    ) -> Publisher<Output> {
        return .init { resumption, downstream in
            Cancellable<Cancellable<Void>>(function: function, file: file, line: line) {
                defer { resumption.resume() }
                guard !self.isComplete else {
                    return .init {
                        try await downstream(.completion(.failure(ConnectableCompletionError())))
                    }
                }
                let downstreamCancellable = await self.subject
                    .asyncPublisher()
                    .sink(downstream)

                if self.autoconnect {
                    try? self.connect(function: function, file: file, line: line)
                }
                return downstreamCancellable
            }.join()
        }
    }

    var isComplete: Bool {
        get { atomicIsComplete.load(ordering: .sequentiallyConsistent) }
    }

    func complete(_ result: Publisher<Output>.Result) async {
        let (success, _) = atomicIsComplete.compareExchange(
            expected: false,
            desired: true,
            ordering: .sequentiallyConsistent
        )
        guard success else { return }
        if ownsSubject {
            try? await subject.send(result)
            _ = await subject.result
        }
    }

    func connect(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line
    ) throws -> Void {
        try promise.succeed()
    }

    func cancel() throws -> Void {
        try cancellable?.cancel()
    }
}
