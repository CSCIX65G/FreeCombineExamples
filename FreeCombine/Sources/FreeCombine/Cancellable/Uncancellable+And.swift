//
//  File.swift
//  
//
//  Created by Van Simmons on 9/23/22.
//

public func and<Left, Right>(
    _ left: Uncancellable<Left>,
    _ right: Uncancellable<Right>
) -> Uncancellable<(Left, Right)> {
    .init {
        async let l = await left.value
        async let r = await right.value
        return await (l, r)
    }
}
