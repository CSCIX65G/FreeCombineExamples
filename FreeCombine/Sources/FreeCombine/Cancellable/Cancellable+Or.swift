//
//  Cancellable+Or.swift
//  
//
//  Created by Van Simmons on 9/13/22.
//
func or<Left, Right>(
    _ left: Cancellable<Left>,
    _ right: Cancellable<Right>
) -> Cancellable<Either<Left, Right>> {
    .init {
        let p: Promise<Either<Left, Right>> = await .init()
        let s: Cancellable<Void> = await or(left.future, right.future).sink {
            try? p.resolve($0)
        }
        return try await withTaskCancellationHandler(
            operation: {
                _ = await s.result
                let result = await p.result
                if Cancellables.isCancelled {
                    throw CancellationError()
                }
                return try result.get()
            },
            onCancel: {
                try? s.cancel()
            }
        )
    }
}
