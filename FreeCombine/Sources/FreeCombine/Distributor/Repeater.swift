//
//  Repeater.swift
//  
//
//  Created by Van Simmons on 10/19/22.
//

final class Repeater<
    Arg: Sendable,
    Return: Sendable
>: Sendable {
    public typealias ResultAndNext = (Result<Return, Swift.Error>, Resumption<Arg>?)

    private let function: StaticString
    private let file: StaticString
    private let line: UInt

    let dispatch: @Sendable (Arg) async throws -> Return
    let cancellable: Cancellable<Never>!

    static func repeater(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        dispatch: @escaping @Sendable (Arg) async throws -> Return,
        returnChannel: Channel<ResultAndNext>
    ) async -> (Resumption<Arg>, Repeater<Arg, Return>) {
        var repeater: Repeater<Arg, Return>!
        let resumption = await withUnfailingResumption(function: function, file: file, line: line) { startup in
            repeater = .init(
                function: function,
                file: file,
                line: line,
                resumption: startup,
                dispatch: dispatch,
                returnChannel: returnChannel
            )
        }
        return (resumption, repeater)
    }

    required init(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        resumption: UnfailingResumption<Resumption<Arg>>,
        dispatch: @escaping @Sendable (Arg) async throws -> Return,
        returnChannel: Channel<ResultAndNext>
    ) {
        self.function = function
        self.file = file
        self.line = line

        self.dispatch = dispatch
        self.cancellable = .init {
            var arg = try await withResumption(resumption.resume)
            while true {
                let result = await Result { try await dispatch(arg) }
                arg = try await withResumption { resumption in
                    do { try returnChannel.tryYield((result, resumption)) }
                    catch { resumption.resume(throwing: CancellationError()) }
                }
            }
        }
    }
}
