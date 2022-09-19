//
//  And.swift
//  
//
//  Created by Van Simmons on 9/18/22.
//
public func and<Left, Right>(
    _ left: Future<Left>,
    _ right: Future<Right>
) -> Future<(Left, Right)> {
    .init { resumption, downstream in
        .init {
            do {
                typealias Z = And<Left, Right>
                let channel = Channel<Z.Action>(buffering: .bufferingOldest(2))
                try await withTaskCancellationHandler(
                    operation: {
                        try await downstream(
                            .success(Z.extract(state: await channel.fold(
                                onStartup: resumption,
                                into: Z.reducer(left: left, right: right)
                            ).value ) )
                        )
                    },
                    onCancel: {
                        channel.finish()
                    }
                )
            } catch {
                return await downstream(.failure(error))
            }
        }
    }
}

public func Anded<Left, Right>(
    _ left: Future<Left>,
    _ right: Future<Right>
) -> Future<(Left, Right)> {
    and(left, right)
}

public extension Future {
    func and<Other>(
        _ other: Future<Other>
    ) -> Future<(Output, Other)> {
        Anded(self, other)
    }
}

public func &&<Left, Right>(
    _ left: Future<Left>,
    _ right: Future<Right>
) -> Future<(Left, Right)> {
    Anded(left, right)
}
