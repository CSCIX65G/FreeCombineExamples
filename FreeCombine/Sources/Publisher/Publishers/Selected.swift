//
//  Selected.swift
//
//
//  Created by Van Simmons on 5/19/22.
//
//  Copyright 2022, ComputeCycles, LLC
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//
import Core
import Queue

public extension Publisher {
    func select<Other>(
        _ other: Publisher<Other>
    ) -> Publisher<Either<Output, Other>> {
        Selected(self, other)
    }
}

public func Selected<Left, Right>(
    _ left: Publisher<Left>,
    _ right: Publisher<Right>
) -> Publisher<Either<Left, Right>> {
    select(left, right)
}

public func select<Left, Right>(
    _ left: Publisher<Left>,
    _ right: Publisher<Right>
) -> Publisher<Either<Left, Right>> {
    .init { resumption, downstream in
        let cancellable = Queue<Select<Left, Right>.Action>(buffering: .bufferingOldest(2))
            .fold(
                onStartup: resumption,
                into: Select<Left, Right>.folder(left: left, right: right, downstream: downstream)
            )
            .cancellable
        return .init {
            try await withTaskCancellationHandler(
                operation: {
                    _ = try await cancellable.value
                    return
                },
                onCancel: { try? cancellable.cancel() }
            )
        }
    }
}

public func select<A, B, C>(
    _ one: Publisher<A>,
    _ two: Publisher<B>,
    _ three: Publisher<C>
) -> Publisher<OneOfThree<A, B, C>> {
    select(select(one, two), three)
        .map { switch $0 {
            case let .left(.left(value)): return .one(value)
            case let .left(.right(value)): return .two(value)
            case let .right(value): return .three(value)
        } }
}

public func select<A, B, C, D>(
    _ one: Publisher<A>,
    _ two: Publisher<B>,
    _ three: Publisher<C>,
    _ four: Publisher<D>
) -> Publisher<OneOfFour<A, B, C, D>> {
    select(select(one, two), select(three, four))
        .map { switch $0 {
            case let .left(.left(value)): return .one(value)
            case let .left(.right(value)): return .two(value)
            case let .right(.left(value)): return .three(value)
            case let .right(.right(value)): return .four(value)
        }  }
}

public func select<A, B, C, D, E>(
    _ one: Publisher<A>,
    _ two: Publisher<B>,
    _ three: Publisher<C>,
    _ four: Publisher<D>,
    _ five: Publisher<E>
) -> Publisher<OneOfFive<A, B, C, D, E>> {
    select(select(select(one, two), select(three, four)), five)
        .map { switch $0 {
            case let .left(.left(.left(one))): return .one(one)
            case let .left(.left(.right(two))): return .two(two)
            case let .left(.right(.left(three))): return .three(three)
            case let .left(.right(.right(four))): return .four(four)
            case let .right(five): return .five(five)
        } }
}

public func select<A, B, C, D, E, F>(
    _ one: Publisher<A>,
    _ two: Publisher<B>,
    _ three: Publisher<C>,
    _ four: Publisher<D>,
    _ five: Publisher<E>,
    _ six: Publisher<F>
) -> Publisher<OneOfSix<A, B, C, D, E, F>> {
    select(select(select(one, two), select(three, four)), select(five, six))
        .map { switch $0 {
            case let .left(.left(.left(one))): return .one(one)
            case let .left(.left(.right(two))): return .two(two)
            case let .left(.right(.left(three))): return .three(three)
            case let .left(.right(.right(four))): return .four(four)
            case let .right(.left(five)): return .five(five)
            case let .right(.right(six)): return .six(six)
        } }
}

public func select<A, B, C, D, E, F, G>(
    _ one: Publisher<A>,
    _ two: Publisher<B>,
    _ three: Publisher<C>,
    _ four: Publisher<D>,
    _ five: Publisher<E>,
    _ six: Publisher<F>,
    _ seven: Publisher<G>
) -> Publisher<OneOfSeven<A, B, C, D, E, F, G>> {
    select(select(select(one, two), select(three, four)), select(select(five, six), seven))
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

public func select<A, B, C, D, E, F, G, H>(
    _ one: Publisher<A>,
    _ two: Publisher<B>,
    _ three: Publisher<C>,
    _ four: Publisher<D>,
    _ five: Publisher<E>,
    _ six: Publisher<F>,
    _ seven: Publisher<G>,
    _ eight: Publisher<H>
) -> Publisher<OneOfEight<A, B, C, D, E, F, G, H>> {
    select(select(select(one, two), select(three, four)), select(select(five, six), select(seven, eight)))
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
