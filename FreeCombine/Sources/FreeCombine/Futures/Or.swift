//
//  Or.swift
//  
//
//  Created by Van Simmons on 9/18/22.
//
public func or<Left, Right>(
    _ left: Future<Left>,
    _ right: Future<Right>
) -> Future<Either<Left, Right>> {
    .init { resumption, downstream in .init {
        do {
            typealias S = Or<Left, Right>
            let channel = Channel<S.Action>(buffering: .bufferingOldest(2))
            try await withTaskCancellationHandler(
                operation: {
                    try await downstream(.success(S.extract(state:
                        await channel.fold(
                            onStartup: resumption,
                            into: S.reducer(left: left, right: right)
                        ).value
                    )))
                },
                onCancel: {
                    channel.finish()
                }
            )
        } catch {
            return await downstream(.failure(error))
        }
    } }
}
