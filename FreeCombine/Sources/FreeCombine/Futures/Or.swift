//
//  Or.swift
//  
//
//  Created by Van Simmons on 9/18/22.
//
public func or<Left, Right>(
    _ left: Future<Left>,
    _ right: Future<Right>
) -> Future<Either<Left, Right>> {
    .init { resumption, downstream in .init {
        do {
            typealias S = Or<Left, Right>
            let channel = Channel<S.Action>(buffering: .bufferingOldest(2))
            try await withTaskCancellationHandler(
                operation: {
                    try await downstream(.success(S.extract(state:
                        await channel.fold(
                            onStartup: resumption,
                            into: S.reducer(left: left, right: right)
                        ).value
                    )))
                },
                onCancel: {
                    channel.finish()
                }
            )
        } catch {
            return await downstream(.failure(error))
        }
    } }
}

public func Ored<Left, Right>(
    _ left: Future<Left>,
    _ right: Future<Right>
) -> Future<Either<Left, Right>> {
    or(left, right)
}

public extension Future {
    func or<Other>(
        _ other: Future<Other>
    ) -> Future<Either<Output, Other>> {
        Ored(self, other)
    }
}

public func ||<Left, Right>(
    _ left: Future<Left>,
    _ right: Future<Right>
) -> Future<Either<Left, Right>> {
    Ored(left, right)
}

public func or<A, B, C>(
    _ one: Future<A>,
    _ two: Future<B>,
    _ three: Future<C>
) -> Future<OneOfThree<A, B, C>> {
    or(or(one, two), three)
        .map { switch $0 {
            case let .left(.left(one)): return .one(one)
            case let .left(.right(two)): return .two(two)
            case let .right(three): return .three(three)
        } }
}

public func or<A, B, C, D>(
    _ one: Future<A>,
    _ two: Future<B>,
    _ three: Future<C>,
    _ four: Future<D>
) -> Future<OneOfFour<A, B, C, D>> {
    or(or(one, two), or(three, four))
        .map { switch $0 {
            case let .left(.left(one)): return .one(one)
            case let .left(.right(two)): return .two(two)
            case let .right(.left(three)): return .three(three)
            case let .right(.right(four)): return .four(four)
        } }
}

public func or<A, B, C, D, E>(
    _ one: Future<A>,
    _ two: Future<B>,
    _ three: Future<C>,
    _ four: Future<D>,
    _ five: Future<E>
) -> Future<OneOfFive<A, B, C, D, E>> {
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
    _ one: Future<A>,
    _ two: Future<B>,
    _ three: Future<C>,
    _ four: Future<D>,
    _ five: Future<E>,
    _ six: Future<F>
) -> Future<OneOfSix<A, B, C, D, E, F>> {
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
    _ one: Future<A>,
    _ two: Future<B>,
    _ three: Future<C>,
    _ four: Future<D>,
    _ five: Future<E>,
    _ six: Future<F>,
    _ seven: Future<G>
) -> Future<OneOfSeven<A, B, C, D, E, F, G>> {
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
    _ one: Future<A>,
    _ two: Future<B>,
    _ three: Future<C>,
    _ four: Future<D>,
    _ five: Future<E>,
    _ six: Future<F>,
    _ seven: Future<G>,
    _ eight: Future<H>
) -> Future<OneOfEight<A, B, C, D, E, F, G, H>> {
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
