//
//  Cancellable+Zip.swift
//
//
//  Created by Van Simmons on 9/6/22.
//
func zip<Left, Right>(
    _ left: Cancellable<Left>,
    _ right: Cancellable<Right>
) -> Cancellable<(Left, Right)> {
    .init {
        let t1 = Cancellable { try await left.value }
        let t2 = Cancellable { try await right.value }
        let lr: Result<Left, Swift.Error> = await t1.result
        let rr: Result<Right, Swift.Error> = await t2.result
        switch (lr, rr) {
            case let (.success(l), .success(r)):
                return (l, r)
            case let (.failure(e), .success):
                throw e
            case let (.success, .failure(e)):
                throw e
            case let (.failure(e), .failure):
                throw e
        }
    }
}
