//
//  Cancellable+Select.swift
//  
//
//  Created by Van Simmons on 9/13/22.
//
func select<Left, Right>(
    _ left: Cancellable<Left>,
    _ right: Cancellable<Right>
) -> Cancellable<Either<Left, Right>> {
    .init {
        let p: Promise<Either<Left, Right>> = await .init()
        let s: Cancellable<Void> = await select(left.future, right.future).sink {
            try? p.resolve($0)
        }
        return try await withTaskCancellationHandler(
            operation: {
                _ = await s.result
                let result = await p.result
                if Task.isCancelled {
                    throw Cancellables.Error.cancelled
                }
                return try result.get()
            },
            onCancel: {
                try? s.cancel()
            }
        )
    }
}
