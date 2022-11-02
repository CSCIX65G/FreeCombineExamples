//
//  ConcurrentFunc.swift
//  
//
//  Created by Van Simmons on 10/19/22.
//

public final class ConcurrentFunc<
    Arg: Sendable,
    Return: Sendable
>: Identifiable, @unchecked Sendable {
    private let originatingFunction: StaticString
    private let file: StaticString
    private let line: UInt

    let asyncFunction: @Sendable (Publisher<Arg>.Result) async throws -> Return
    private(set) var cancellable: Cancellable<Return>! = .none

    public var id: ObjectIdentifier { .init(self) }

    private static func invoke(
        me: ConcurrentFunc<Arg, Return>,
        asyncFunction: @escaping @Sendable (Publisher<Arg>.Result) async throws -> Return,
        arg: inout Publisher<Arg>.Result,
        returnChannel: Channel<Next>
    ) async throws -> Return {
        var result = Result<Return, Swift.Error>.failure(InvocationError())
        while true {
            result = await Result { try await asyncFunction(arg) }
            switch arg {
                case .completion(.finished):
                    throw CompletionError(completion: .finished)
                case let .completion(.failure(error)):
                    throw error
                case .value:
                    arg = try await withResumption { resumption in
                        do {
                            try returnChannel.tryYield(.init(
                                result: result, invocation: .init(function: me, resumption: resumption)
                            ))
                        }
                        catch { resumption.resume(throwing: BufferError()) }
                    }
            }
        }
        return try result.get()
    }

    init(
        originatingFunction: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        resumption: UnfailingResumption<Resumption<Publisher<Arg>.Result>>,
        function: @escaping @Sendable (Publisher<Arg>.Result) async throws -> Return,
        returnChannel: Channel<Next>
    ) {
        self.originatingFunction = originatingFunction
        self.file = file
        self.line = line

        self.asyncFunction = function
        self.cancellable = .init {
            var arg = try await withResumption(resumption.resume)
            return try await Self.invoke(me: self, asyncFunction: function, arg: &arg, returnChannel: returnChannel)
        }
    }

    init(
        originatingFunction: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        function: @escaping @Sendable (Publisher<Arg>.Result) async throws -> Return,
        arg invocationArg: Arg,
        returnChannel: Channel<Next>
    ) {
        self.originatingFunction = originatingFunction
        self.file = file
        self.line = line

        self.asyncFunction = function
        self.cancellable = .init {
            var arg = Publisher<Arg>.Result.value(invocationArg)
            return try await Self.invoke(me: self, asyncFunction: function, arg: &arg, returnChannel: returnChannel)
        }
    }
}

public extension ConcurrentFunc {
    struct Invocation: Sendable {
        let function: ConcurrentFunc<Arg, Return>
        let resumption: Resumption<Publisher<Arg>.Result>

        public init(function: ConcurrentFunc<Arg, Return>, resumption: Resumption<Publisher<Arg>.Result>) {
            self.function = function
            self.resumption = resumption
        }

        public init(
            originatingFunction: StaticString = #function,
            file: StaticString = #file,
            line: UInt = #line,
            dispatch: @escaping @Sendable (Publisher<Arg>.Result) async throws -> Return,
            returnChannel: Channel<Next>
        ) async {
            var function: ConcurrentFunc<Arg, Return>!
            let resumption = await withUnfailingResumption(function: originatingFunction, file: file, line: line) { startup in
                function = .init(
                    originatingFunction: originatingFunction,
                    file: file,
                    line: line,
                    resumption: startup,
                    function: dispatch,
                    returnChannel: returnChannel
                )
            }
            self.init(function: function, resumption: resumption)
        }

        public func callAsFunction(_ arg: Arg) -> Void {
            resumption.resume(returning: .value(arg))
        }
        public func callAsFunction(_ completion: Publishers.Completion) -> Void {
            resumption.resume(returning: .completion(completion))
        }
        public func callAsFunction(_ error: Swift.Error) -> Void {
            resumption.resume(throwing: error)
        }
        public func callAsFunction() -> Void {
            resumption.resume(returning: .completion(.finished))
        }
    }

    struct Next: Sendable {
        public let result: Result<Return, Swift.Error>
        public let invocation: Invocation
        public var id: ObjectIdentifier { invocation.function.id }
    }
}
