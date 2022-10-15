//
//  Cancellable+And.swift
//
//
//  Created by Van Simmons on 9/6/22.
//

/*:
 Bad implementation.
 */
func and<Left, Right>(
    _ left: Cancellable<Left>,
    _ right: Cancellable<Right>
) -> Cancellable<(Left, Right)> {
    and(left.future, right.future).futureValue
}

public func Anded<Left, Right>(
    _ left: Cancellable<Left>,
    _ right: Cancellable<Right>
) -> Cancellable<(Left, Right)> {
    and(left, right)
}

public extension Cancellable {
    func and<Other>(
        _ other: Cancellable<Other>
    ) -> Cancellable<(Output, Other)> {
        Anded(self, other)
    }
}

public func &&<Left, Right>(
    _ left: Cancellable<Left>,
    _ right: Cancellable<Right>
) -> Cancellable<(Left, Right)> {
    Anded(left, right)
}

public func and<A, B, C>(
    _ one: Cancellable<A>,
    _ two: Cancellable<B>,
    _ three: Cancellable<C>
) -> Cancellable<(A, B, C)> {
    and(and(one, two), three)
        .map { ($0.0.0, $0.0.1, $0.1) }
}

public func and<A, B, C, D>(
    _ one: Cancellable<A>,
    _ two: Cancellable<B>,
    _ three: Cancellable<C>,
    _ four: Cancellable<D>
) -> Cancellable<(A, B, C, D)> {
    and(and(one, two), and(three, four))
        .map { ($0.0.0, $0.0.1, $0.1.0, $0.1.1) }
}

public func and<A, B, C, D, E>(
    _ one: Cancellable<A>,
    _ two: Cancellable<B>,
    _ three: Cancellable<C>,
    _ four: Cancellable<D>,
    _ five: Cancellable<E>
) -> Cancellable<(A, B, C, D, E)> {
    and(and(and(one, two), and(three, four)), five)
        .map { ($0.0.0.0, $0.0.0.1, $0.0.1.0, $0.0.1.1, $0.1) }
}

public func and<A, B, C, D, E, F>(
    _ one: Cancellable<A>,
    _ two: Cancellable<B>,
    _ three: Cancellable<C>,
    _ four: Cancellable<D>,
    _ five: Cancellable<E>,
    _ six: Cancellable<F>
) -> Cancellable<(A, B, C, D, E, F)> {
    and(and(and(one, two), and(three, four)), and(five, six))
        .map { ($0.0.0.0, $0.0.0.1, $0.0.1.0, $0.0.1.1, $0.1.0, $0.1.1) }
}

public func and<A, B, C, D, E, F, G>(
    _ one: Cancellable<A>,
    _ two: Cancellable<B>,
    _ three: Cancellable<C>,
    _ four: Cancellable<D>,
    _ five: Cancellable<E>,
    _ six: Cancellable<F>,
    _ seven: Cancellable<G>
) -> Cancellable<(A, B, C, D, E, F, G)> {
    and(and(and(one, two), and(three, four)), and(and(five, six), seven))
        .map { ($0.0.0.0, $0.0.0.1, $0.0.1.0, $0.0.1.1, $0.1.0.0, $0.1.0.1, $0.1.1) }
}

public func and<A, B, C, D, E, F, G, H>(
    _ one: Cancellable<A>,
    _ two: Cancellable<B>,
    _ three: Cancellable<C>,
    _ four: Cancellable<D>,
    _ five: Cancellable<E>,
    _ six: Cancellable<F>,
    _ seven: Cancellable<G>,
    _ eight: Cancellable<H>
) -> Cancellable<(A, B, C, D, E, F, G, H)> {
    and(and(and(one, two), and(three, four)), and(and(five, six), and(seven, eight)))
        .map { ($0.0.0.0, $0.0.0.1, $0.0.1.0, $0.0.1.1, $0.1.0.0, $0.1.0.1, $0.1.1.0, $0.1.1.1) }
}
