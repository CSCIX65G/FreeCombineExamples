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
        let channel = Channel<Or<Left, Right>.Action>(buffering: .bufferingOldest(2))
        let folder = Or<Left, Right>.folder(left: left, right: right)
        let fold = channel.fold(onStartup: resumption, into: folder)
        await withTaskCancellationHandler(
            operation: {
                do { try await downstream(.success(Or<Left, Right>.extract(state: fold.value))) }
                catch { await downstream(.failure(error)) }
            },
            onCancel: channel.finish
        )
    } }
}

@inlinable
public func Ored<Left, Right>(
    _ left: Future<Left>,
    _ right: Future<Right>
) -> Future<Either<Left, Right>> {
    or(left, right)
}

public extension Future {
    @inlinable
    func or<Other>(
        _ other: Future<Other>
    ) -> Future<Either<Output, Other>> {
        Ored(self, other)
    }
}

@inlinable
public func ||<Left, Right>(
    _ left: Future<Left>,
    _ right: Future<Right>
) -> Future<Either<Left, Right>> {
    Ored(left, right)
}

@inlinable
public func or<A, B, C>(
    _ one: Future<A>,
    _ two: Future<B>,
    _ three: Future<C>
) -> Future<OneOfThree<A, B, C>> {
    ((one || two) || three)
        .map { switch $0 {
            case let .left(.left(one)): return .one(one)
            case let .left(.right(two)): return .two(two)
            case let .right(three): return .three(three)
        } }
}

@inlinable
public func or<A, B, C, D>(
    _ one: Future<A>,
    _ two: Future<B>,
    _ three: Future<C>,
    _ four: Future<D>
) -> Future<OneOfFour<A, B, C, D>> {
    ((one || two) || (three || four))
        .map { switch $0 {
            case let .left(.left(one)): return .one(one)
            case let .left(.right(two)): return .two(two)
            case let .right(.left(three)): return .three(three)
            case let .right(.right(four)): return .four(four)
        } }
}

@inlinable
public func or<A, B, C, D, E>(
    _ one: Future<A>,
    _ two: Future<B>,
    _ three: Future<C>,
    _ four: Future<D>,
    _ five: Future<E>
) -> Future<OneOfFive<A, B, C, D, E>> {
    (((one || two) || (three || four)) || five)
        .map { switch $0 {
            case let .left(.left(.left(one))): return .one(one)
            case let .left(.left(.right(two))): return .two(two)
            case let .left(.right(.left(three))): return .three(three)
            case let .left(.right(.right(four))): return .four(four)
            case let .right(five): return .five(five)
        } }
}

@inlinable
public func or<A, B, C, D, E, F>(
    _ one: Future<A>,
    _ two: Future<B>,
    _ three: Future<C>,
    _ four: Future<D>,
    _ five: Future<E>,
    _ six: Future<F>
) -> Future<OneOfSix<A, B, C, D, E, F>> {
    (((one || two) || (three || four)) || (five || six))
        .map { switch $0 {
            case let .left(.left(.left(one))): return .one(one)
            case let .left(.left(.right(two))): return .two(two)
            case let .left(.right(.left(three))): return .three(three)
            case let .left(.right(.right(four))): return .four(four)
            case let .right(.left(five)): return .five(five)
            case let .right(.right(six)): return .six(six)
        } }
}

@inlinable
public func or<A, B, C, D, E, F, G>(
    _ one: Future<A>,
    _ two: Future<B>,
    _ three: Future<C>,
    _ four: Future<D>,
    _ five: Future<E>,
    _ six: Future<F>,
    _ seven: Future<G>
) -> Future<OneOfSeven<A, B, C, D, E, F, G>> {
    (((one || two) || (three || four)) || ((five || six) || seven))
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

@inlinable
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
    (((one || two) || (three || four)) || ((five || six) || (seven || eight)))
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
