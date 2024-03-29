//
//  ConcurrentFunc.swift
//  
//
//  Created by Van Simmons on 10/19/22.
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
import Core
import Queue
import SendableAtomics

public struct InvocationError: Swift.Error, Sendable, Equatable { }

public struct ConcurrentFunc<Arg: Sendable, Return: Sendable>: @unchecked Sendable, Identifiable {
    public let id: ObjectIdentifier
    public let dispatch: ConcurrentFunc<Arg, Return>.Dispatch
    let resumption: Resumption<(Queue<Next>, Publisher<Arg>.Result)>

    public init(
        dispatch: ConcurrentFunc<Arg, Return>.Dispatch,
        resumption: Resumption<(Queue<Next>, Publisher<Arg>.Result)>
    ) {
        self.id = .init(dispatch)
        self.dispatch = dispatch
        self.resumption = resumption
    }

    public init(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        _ dispatch: @Sendable @escaping (Publisher<Arg>.Result) async throws -> Return
    ) async {
        var localDispatch: ConcurrentFunc<Arg, Return>.Dispatch!
        let resumption = await unfailingPause(function: function, file: file, line: line) { startup in
            localDispatch = .init(
                function: function,
                file: file,
                line: line,
                resumption: startup,
                asyncFunction: dispatch
            )
        }
        self.init(dispatch: localDispatch, resumption: resumption)
    }
}

public extension ConcurrentFunc {
    var result: AsyncResult<Return, Swift.Error> {
        get async { await dispatch.result }
    }
    var value: Return {
        get async throws { try await dispatch.value }
    }

    func callAsFunction(returnChannel: Queue<Next>, arg: Arg) throws -> Void {
        try resumption.resume(returning: (returnChannel,.value(arg)))
    }
    func callAsFunction(returnChannel: Queue<Next>, error: Swift.Error) throws -> Void {
        try resumption.resume(returning: (returnChannel, .completion(.failure(error))))
    }
    func callAsFunction(returnChannel: Queue<Next>, completion: Publishers.Completion) throws -> Void {
        try resumption.resume(returning: (returnChannel, .completion(completion)))
    }
    func callAsFunction(returnChannel: Queue<Next>, _ resultArg: Publisher<Arg>.Result) throws -> Void {
        try resumption.resume(returning: (returnChannel, resultArg))
    }
}

public extension ConcurrentFunc where Arg == Void {
    func callAsFunction(returnChannel: Queue<Next>) -> Void {
        try! resumption.resume(returning: (returnChannel, .value(())))
    }
}

public extension ConcurrentFunc {
    final class Dispatch: Identifiable, @unchecked Sendable {
        private let function: StaticString
        private let file: StaticString
        private let line: UInt

        public let dispatch: @Sendable (Publisher<Arg>.Result) async throws -> Return
        public private(set) var cancellable: Cancellable<Return>! = .none

        public init(
            function: StaticString = #function,
            file: StaticString = #file,
            line: UInt = #line,
            resumption: UnfailingResumption<Resumption<(Queue<Next>, Publisher<Arg>.Result)>>,
            asyncFunction: @Sendable @escaping (Publisher<Arg>.Result) async throws -> Return
        ) {
            self.function = function
            self.file = file
            self.line = line

            self.dispatch = asyncFunction
            self.cancellable = .init {
                var (returnChannel, arg) = try await pause(
                    function: function,
                    file: file,
                    line: line
                ) {
                    try! resumption.resume(returning: $0)
                }
                var result = AsyncResult<Return, Swift.Error>.failure(InvocationError())
                while true {
                    result = await AsyncResult { try await asyncFunction(arg) }
                    switch arg {
                        case .completion(.finished):
                            throw CompletionError(completion: .finished)
                        case let .completion(.failure(error)):
                            throw error
                        case .value:
                            (returnChannel, arg) = try await pause { resumption in
                                do { try returnChannel.tryYield(
                                    .init(result: result, concurrentFunc: .init(dispatch: self, resumption: resumption))
                                ) }
                                catch {
                                    try! resumption.resume(throwing: error)
                                }
                            }
                    }
                }
                return try result.get()
            }
        }
        public var result: AsyncResult<Return, Swift.Error> {
            get async { await cancellable.result.asyncResult }
        }
        public var value: Return {
            get async throws { try await cancellable.value }
        }
    }
}

public extension ConcurrentFunc {
    struct Next: @unchecked Sendable {
        public var id: ObjectIdentifier { concurrentFunc.dispatch.id }
        public let result: AsyncResult<Return, Swift.Error>
        public let concurrentFunc: ConcurrentFunc<Arg, Return>

        public func callAsFunction(returnChannel: Queue<Next>, arg: Arg) throws -> Void {
            try concurrentFunc(returnChannel: returnChannel, arg: arg)
        }
        public func callAsFunction(returnChannel: Queue<Next>, completion: Publishers.Completion) throws -> Void {
            try concurrentFunc(returnChannel: returnChannel, completion: completion)
        }
        public func callAsFunction(returnChannel: Queue<Next>, resultArg: Publisher<Arg>.Result) throws -> Void {
            try concurrentFunc(returnChannel: returnChannel, resultArg)
        }
    }
}
