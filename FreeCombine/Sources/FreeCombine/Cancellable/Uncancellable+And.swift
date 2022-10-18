//
//  Uncancellable+And.swift
//  
//
//  Created by Van Simmons on 9/23/22.
//

func and<Left, Right>(
    _ left: Uncancellable<Left>,
    _ right: Uncancellable<Right>
) -> Uncancellable<(Left, Right)> {
    .init {
        async let leftValue = await left.value
        async let rightValue = await right.value
        return await (leftValue, rightValue)
    }
}

public func Anded<Left, Right>(
    _ left: Uncancellable<Left>,
    _ right: Uncancellable<Right>
) -> Uncancellable<(Left, Right)> {
    and(left, right)
}

public extension Uncancellable {
    func and<Other>(
        _ other: Uncancellable<Other>
    ) -> Uncancellable<(Output, Other)> {
        Anded(self, other)
    }
}

public func &&<Left, Right>(
    _ left: Uncancellable<Left>,
    _ right: Uncancellable<Right>
) -> Uncancellable<(Left, Right)> {
    Anded(left, right)
}

public func and<A, B, C>(
    _ one: Uncancellable<A>,
    _ two: Uncancellable<B>,
    _ three: Uncancellable<C>
) -> Uncancellable<(A, B, C)> {
    and(and(one, two), three)
        .map { ($0.0.0, $0.0.1, $0.1) }
}

public func and<A, B, C, D>(
    _ one: Uncancellable<A>,
    _ two: Uncancellable<B>,
    _ three: Uncancellable<C>,
    _ four: Uncancellable<D>
) -> Uncancellable<(A, B, C, D)> {
    and(and(one, two), and(three, four))
        .map { ($0.0.0, $0.0.1, $0.1.0, $0.1.1) }
}

public func and<A, B, C, D, E>(
    _ one: Uncancellable<A>,
    _ two: Uncancellable<B>,
    _ three: Uncancellable<C>,
    _ four: Uncancellable<D>,
    _ five: Uncancellable<E>
) -> Uncancellable<(A, B, C, D, E)> {
    and(and(and(one, two), and(three, four)), five)
        .map { ($0.0.0.0, $0.0.0.1, $0.0.1.0, $0.0.1.1, $0.1) }
}

public func and<A, B, C, D, E, F>(
    _ one: Uncancellable<A>,
    _ two: Uncancellable<B>,
    _ three: Uncancellable<C>,
    _ four: Uncancellable<D>,
    _ five: Uncancellable<E>,
    _ six: Uncancellable<F>
) -> Uncancellable<(A, B, C, D, E, F)> {
    and(and(and(one, two), and(three, four)), and(five, six))
        .map { ($0.0.0.0, $0.0.0.1, $0.0.1.0, $0.0.1.1, $0.1.0, $0.1.1) }
}

public func and<A, B, C, D, E, F, G>(
    _ one: Uncancellable<A>,
    _ two: Uncancellable<B>,
    _ three: Uncancellable<C>,
    _ four: Uncancellable<D>,
    _ five: Uncancellable<E>,
    _ six: Uncancellable<F>,
    _ seven: Uncancellable<G>
) -> Uncancellable<(A, B, C, D, E, F, G)> {
    and(and(and(one, two), and(three, four)), and(and(five, six), seven))
        .map { ($0.0.0.0, $0.0.0.1, $0.0.1.0, $0.0.1.1, $0.1.0.0, $0.1.0.1, $0.1.1) }
}

public func and<A, B, C, D, E, F, G, H>(
    _ one: Uncancellable<A>,
    _ two: Uncancellable<B>,
    _ three: Uncancellable<C>,
    _ four: Uncancellable<D>,
    _ five: Uncancellable<E>,
    _ six: Uncancellable<F>,
    _ seven: Uncancellable<G>,
    _ eight: Uncancellable<H>
) -> Uncancellable<(A, B, C, D, E, F, G, H)> {
    and(and(and(one, two), and(three, four)), and(and(five, six), and(seven, eight)))
        .map { ($0.0.0.0, $0.0.0.1, $0.0.1.0, $0.0.1.1, $0.1.0.0, $0.1.0.1, $0.1.1.0, $0.1.1.1) }
}
