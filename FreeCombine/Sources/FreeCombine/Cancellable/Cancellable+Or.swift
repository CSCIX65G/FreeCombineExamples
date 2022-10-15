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
    or(left.future, right.future).futureValue
}

public func Ored<Left, Right>(
    _ left: Cancellable<Left>,
    _ right: Cancellable<Right>
) -> Cancellable<Either<Left, Right>> {
    or(left, right)
}

public extension Cancellable {
    func or<Other>(
        _ other: Cancellable<Other>
    ) -> Cancellable<Either<Output, Other>> {
        Ored(self, other)
    }
}

public func ||<Left, Right>(
    _ left: Cancellable<Left>,
    _ right: Cancellable<Right>
) -> Cancellable<Either<Left, Right>> {
    Ored(left, right)
}

public func or<A, B, C>(
    _ one: Cancellable<A>,
    _ two: Cancellable<B>,
    _ three: Cancellable<C>
) -> Cancellable<OneOfThree<A, B, C>> {
    or(or(one, two), three)
        .map { switch $0 {
            case let .left(.left(one)): return .one(one)
            case let .left(.right(two)): return .two(two)
            case let .right(three): return .three(three)
        } }
}

public func or<A, B, C, D>(
    _ one: Cancellable<A>,
    _ two: Cancellable<B>,
    _ three: Cancellable<C>,
    _ four: Cancellable<D>
) -> Cancellable<OneOfFour<A, B, C, D>> {
    or(or(one, two), or(three, four))
        .map { switch $0 {
            case let .left(.left(one)): return .one(one)
            case let .left(.right(two)): return .two(two)
            case let .right(.left(three)): return .three(three)
            case let .right(.right(four)): return .four(four)
        } }
}

public func or<A, B, C, D, E>(
    _ one: Cancellable<A>,
    _ two: Cancellable<B>,
    _ three: Cancellable<C>,
    _ four: Cancellable<D>,
    _ five: Cancellable<E>
) -> Cancellable<OneOfFive<A, B, C, D, E>> {
    or(or(or(one, two), or(three, four)), five)
        .map { switch $0 {
            case let .left(.left(.left(one))): return .one(one)
            case let .left(.left(.right(two))): return .two(two)
            case let .left(.right(.left(three))): return .three(three)
            case let .left(.right(.right(four))): return .four(four)
            case let .right(five): return .five(five)
        } }
}

public func or<A, B, C, D, E, F>(
    _ one: Cancellable<A>,
    _ two: Cancellable<B>,
    _ three: Cancellable<C>,
    _ four: Cancellable<D>,
    _ five: Cancellable<E>,
    _ six: Cancellable<F>
) -> Cancellable<OneOfSix<A, B, C, D, E, F>> {
    or(or(or(one, two), or(three, four)), or(five, six))
        .map { switch $0 {
            case let .left(.left(.left(one))): return .one(one)
            case let .left(.left(.right(two))): return .two(two)
            case let .left(.right(.left(three))): return .three(three)
            case let .left(.right(.right(four))): return .four(four)
            case let .right(.left(five)): return .five(five)
            case let .right(.right(six)): return .six(six)
        } }
}

public func or<A, B, C, D, E, F, G>(
    _ one: Cancellable<A>,
    _ two: Cancellable<B>,
    _ three: Cancellable<C>,
    _ four: Cancellable<D>,
    _ five: Cancellable<E>,
    _ six: Cancellable<F>,
    _ seven: Cancellable<G>
) -> Cancellable<OneOfSeven<A, B, C, D, E, F, G>> {
    or(or(or(one, two), or(three, four)), or(or(five, six), seven))
        .map { switch $0 {
            case let .left(.left(.left(one))): return .one(one)
            case let .left(.left(.right(two))): return .two(two)
            case let .left(.right(.left(three))): return .three(three)
            case let .left(.right(.right(four))): return .four(four)
            case let .right(.left(.left(five))): return .five(five)
            case let .right(.left(.right(six))): return .six(six)
            case let .right(.right(seven)): return .seven(seven)
        } }
}

public func or<A, B, C, D, E, F, G, H>(
    _ one: Cancellable<A>,
    _ two: Cancellable<B>,
    _ three: Cancellable<C>,
    _ four: Cancellable<D>,
    _ five: Cancellable<E>,
    _ six: Cancellable<F>,
    _ seven: Cancellable<G>,
    _ eight: Cancellable<H>
) -> Cancellable<OneOfEight<A, B, C, D, E, F, G, H>> {
    or(or(or(one, two), or(three, four)), or(or(five, six), or(seven, eight)))
        .map { switch $0 {
            case let .left(.left(.left(one))): return .one(one)
            case let .left(.left(.right(two))): return .two(two)
            case let .left(.right(.left(three))): return .three(three)
            case let .left(.right(.right(four))): return .four(four)
            case let .right(.left(.left(five))): return .five(five)
            case let .right(.left(.right(six))): return .six(six)
            case let .right(.right(.left(seven))): return .seven(seven)
            case let .right(.right(.right(eight))): return .eight(eight)
        } }
}
