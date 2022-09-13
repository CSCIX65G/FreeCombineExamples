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
        var cancan: Cancellable<Cancellable<Void>>!
        let result: Result<(Left, Right), Swift.Error> = try await withResumption { resumption in
            cancan = Cancellable {
                await zip(left.future, right.future).sink { result in
                    resumption.resume(returning: result)
                }
            }
        }
        _ = await cancan.join().result
        return try result.get()
    }
}
