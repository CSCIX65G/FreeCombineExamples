//
//  Cancellable+And.swift
//
//
//  Created by Van Simmons on 9/6/22.
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
