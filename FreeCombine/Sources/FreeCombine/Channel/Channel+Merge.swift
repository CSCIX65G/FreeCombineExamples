//
//  Channel+Merge.swift
//  
//
//  Created by Van Simmons on 9/24/22.
//
func merge<A, B>(
    _ left: Channel<A>,
    _ right: Channel<B>
) -> Channel<Either<A, B>> {
    Channel<Either<A, B>>.init(buffering: .unbounded)
}
