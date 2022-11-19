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

    private init(
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
                            do { try returnChannel.tryYield(Next(
                                result: result,
                                invocation: .init(function: self, resumption: resumption)
                            ) ) }
                            catch { resumption.resume(throwing: BufferError()) }
                        }
                }
            }
            return try result.get()
        }
    }
}

public extension ConcurrentFunc {
    struct Invocation: Sendable {
        let dispatch: ConcurrentFunc<Arg, Return>
        let resumption: Resumption<Publisher<Arg>.Result>

        init(function: ConcurrentFunc<Arg, Return>, resumption: Resumption<Publisher<Arg>.Result>) {
            self.dispatch = function
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
        public var id: ObjectIdentifier { invocation.dispatch.id }
        public let result: Result<Return, Swift.Error>
        public let invocation: Invocation
    }
}

public extension ConcurrentFunc.Invocation where Arg == Void {
    func callAsFunction() -> Void {
        resumption.resume(returning: .value(()))
    }
}
