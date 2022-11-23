//
//  ConcurrentFunc.swift
//  
//
//  Created by Van Simmons on 10/19/22.
//

public struct ConcurrentFunc<Arg, Return>: @unchecked Sendable, Identifiable {
    public let id: ObjectIdentifier
    let dispatch: ConcurrentFunc<Arg, Return>.Dispatch
    let resumption: Resumption<(Channel<Next>, Publisher<Arg>.Result)>

    init(
        dispatch: ConcurrentFunc<Arg, Return>.Dispatch,
        resumption: Resumption<(Channel<Next>, Publisher<Arg>.Result)>
    ) {
        self.id = .init(dispatch)
        self.dispatch = dispatch
        self.resumption = resumption
    }

    public init(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        _ dispatch: @escaping @Sendable (Publisher<Arg>.Result) async throws -> Return
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

    var result: Result<Return, Swift.Error> {
        get async { await dispatch.result }
    }
    var value: Return {
        get async throws { try await dispatch.value }
    }

    public func callAsFunction(returnChannel: Channel<Next>, arg: Arg) throws -> Void {
        try resumption.tryResume(returning: (returnChannel,.value(arg)))
    }
    public func callAsFunction(returnChannel: Channel<Next>, error: Swift.Error) throws -> Void {
        try resumption.tryResume(returning: (returnChannel, .completion(.failure(error))))
    }
    public func callAsFunction(returnChannel: Channel<Next>, completion: Publishers.Completion) throws -> Void {
        try resumption.tryResume(returning: (returnChannel, .completion(completion)))
    }
    public func callAsFunction(returnChannel: Channel<Next>, _ resultArg: Publisher<Arg>.Result) throws -> Void {
        try resumption.tryResume(returning: (returnChannel, resultArg))
    }
}

public extension ConcurrentFunc where Arg == Void {
    func callAsFunction(returnChannel: Channel<Next>) -> Void {
        resumption.resume(returning: (returnChannel, .value(())))
    }
}

extension ConcurrentFunc {
    final class Dispatch: Identifiable, @unchecked Sendable {
        private let function: StaticString
        private let file: StaticString
        private let line: UInt

        let dispatch: @Sendable (Publisher<Arg>.Result) async throws -> Return
        private(set) var cancellable: Cancellable<Return>! = .none

        init(
            function: StaticString = #function,
            file: StaticString = #file,
            line: UInt = #line,
            resumption: UnfailingResumption<Resumption<(Channel<Next>, Publisher<Arg>.Result)>>,
            asyncFunction: @escaping @Sendable (Publisher<Arg>.Result) async throws -> Return
        ) {
            self.function = function
            self.file = file
            self.line = line

            self.dispatch = asyncFunction
            self.cancellable = .init {
                var (returnChannel, arg) = try await pause(resumption.resume)
                var result = Result<Return, Swift.Error>.failure(InvocationError())
                while true {
                    result = await Result { try await asyncFunction(arg) }
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
                                    resumption.resume(throwing: error)
                                }
                            }
                    }
                }
                return try result.get()
            }
        }
        var result: Result<Return, Swift.Error> {
            get async { await cancellable.result }
        }
        var value: Return {
            get async throws { try await cancellable.value }
        }
    }
}

public extension ConcurrentFunc {
    struct Next: @unchecked Sendable {
        public var id: ObjectIdentifier { concurrentFunc.dispatch.id }
        public let result: Result<Return, Swift.Error>
        public let concurrentFunc: ConcurrentFunc<Arg, Return>

        public func callAsFunction(returnChannel: Channel<Next>, arg: Arg) throws -> Void {
            try concurrentFunc(returnChannel: returnChannel, arg: arg)
        }
        public func callAsFunction(returnChannel: Channel<Next>, completion: Publishers.Completion) throws -> Void {
            try concurrentFunc(returnChannel: returnChannel, completion: completion)
        }
        public func callAsFunction(returnChannel: Channel<Next>, resultArg: Publisher<Arg>.Result) throws -> Void {
            try concurrentFunc(returnChannel: returnChannel, resultArg)
        }
    }
}
