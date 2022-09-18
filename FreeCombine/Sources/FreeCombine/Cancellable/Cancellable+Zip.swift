//
//  Cancellable+Zip.swift
//
//
//  Created by Van Simmons on 9/6/22.
//

/*:
 Bad implementation.
 */
func zip<Left, Right>(
    _ left: Cancellable<Left>,
    _ right: Cancellable<Right>
) -> Cancellable<(Left, Right)> {
    .init {
        typealias Error = Cancellables.Error
        let p: Promise<(Left, Right)> = await .init()
        let z: Cancellable<Void> = await and(left.future, right.future).sink {
            try? p.resolve($0)
        }
        return try await withTaskCancellationHandler(
            operation: {
                _ = await z.result
                let result = await p.result
                if Task.isCancelled { throw Error.cancelled }
                return try result.get()
            },
            onCancel: {
                try? z.cancel()
            }
        )
    }
}
