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
    private let function: StaticString
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
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        resumption: UnfailingResumption<Resumption<Publisher<Arg>.Result>>,
        asyncFunction: @escaping @Sendable (Publisher<Arg>.Result) async throws -> Return,
        returnChannel: Channel<Next>
    ) {
        self.function = function
        self.file = file
        self.line = line

        self.asyncFunction = asyncFunction
        self.cancellable = .init {
            var arg = try await withResumption(resumption.resume)
            return try await Self.invoke(me: self, asyncFunction: asyncFunction, arg: &arg, returnChannel: returnChannel)
        }
    }

    init(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        asyncFunction: @escaping @Sendable (Publisher<Arg>.Result) async throws -> Return,
        arg invocationArg: Arg,
        returnChannel: Channel<Next>
    ) {
        self.function = function
        self.file = file
        self.line = line

        self.asyncFunction = asyncFunction
        self.cancellable = .init {
            var arg = Publisher<Arg>.Result.value(invocationArg)
            return try await Self.invoke(me: self, asyncFunction: asyncFunction, arg: &arg, returnChannel: returnChannel)
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
                    function: originatingFunction,
                    file: file,
                    line: line,
                    resumption: startup,
                    asyncFunction: dispatch,
                    returnChannel: returnChannel
                )
            }
            self.init(function: function, resumption: resumption)
        }

        public func callAsFunction(_ arg: Arg) -> Void {
            resumption.resume(returning: .value(arg))
        }
        public func callAsFunction(completion: Publishers.Completion) -> Void {
            resumption.resume(returning: .completion(completion))
        }
        public func callAsFunction(resultArg: Publisher<Arg>.Result) -> Void {
            resumption.resume(returning: resultArg)
        }
    }

    struct Next: Sendable {
        public let result: Result<Return, Swift.Error>
        public let invocation: Invocation
        public var id: ObjectIdentifier { invocation.function.id }
    }
}

public extension ConcurrentFunc.Invocation where Arg == Void {
    func callAsFunction() -> Void {
        resumption.resume(returning: .value(()))
    }
}
