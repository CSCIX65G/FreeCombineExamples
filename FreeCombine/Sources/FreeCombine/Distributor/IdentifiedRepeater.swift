//
//  Repeater.swift
//  
//
//  Created by Van Simmons on 10/19/22.
//

final class IdentifiedRepeater<
    ID: Hashable & Sendable,
    Arg: Sendable,
    Return: Sendable
>: Identifiable, Sendable {
    public struct Next: Sendable, Identifiable {
        let id: ID
        let result: Result<Return, Swift.Error>
        let resumption: Resumption<Publisher<Arg>.Result>
    }

    private let function: StaticString
    private let file: StaticString
    private let line: UInt

    let id: ID
    let dispatch: @Sendable (Publisher<Arg>.Result) async throws -> Return
    let cancellable: Cancellable<Void>!

    required init(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        id: ID,
        resumption: UnfailingResumption<Resumption<Publisher<Arg>.Result>>,
        dispatch: @escaping @Sendable (Publisher<Arg>.Result) async throws -> Return,
        returnChannel: Channel<Next>
    ) {
        self.function = function
        self.file = file
        self.line = line

        self.id = id
        self.dispatch = dispatch
        self.cancellable = .init {
            var arg = try await withResumption(resumption.resume)
            while true {
                let result = await Result { try await dispatch(arg) }
                arg = try await withResumption { resumption in
                    do { try returnChannel.tryYield(.init(id: id, result: result, resumption: resumption)) }
                    catch { resumption.resume(throwing: BufferError()) }
                }
            }
        }
    }
}

extension IdentifiedRepeater {
    public struct First: Sendable, Identifiable {
        let resumption: Resumption<Publisher<Arg>.Result>
        let repeater: IdentifiedRepeater<ID, Arg, Return>
        public var id: ID { repeater.id }
    }

    static func first(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        id: ID,
        dispatch: @escaping @Sendable (Publisher<Arg>.Result) async throws -> Return,
        returnChannel: Channel<Next>
    ) async -> First {
        var repeater: IdentifiedRepeater<ID, Arg, Return>!
        let resumption = await withUnfailingResumption(function: function, file: file, line: line) { startup in
            repeater = .init(
                function: function,
                file: file,
                line: line,
                id: id,
                resumption: startup,
                dispatch: dispatch,
                returnChannel: returnChannel
            )
        }
        return .init(resumption: resumption, repeater: repeater)
    }
}
