//
//  And.swift
//  
//
//  Created by Van Simmons on 9/18/22.
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
import Atomics
import Core
import Queue

extension ManagedAtomic: @unchecked Sendable where Value: Sendable { }

@Sendable public func and<Left: Sendable, Right: Sendable>(
    _ left: Future<Left>,
    _ right: Future<Right>
) -> Future<(Left, Right)> {
    .init { resumption, downstream in .init {
        let queue = Queue<AsyncResult<(Left, Right), Swift.Error>>.init(buffering: .bufferingOldest(1))
        return await withTaskCancellationHandler(
            operation: {
                var iterator = queue.stream.makeAsyncIterator()
                let leftValue = ManagedAtomic(Box(value: Left?.none))
                let rightValue = ManagedAtomic(Box(value: Right?.none))
                let leftCancellable = await left { lResult in
                    switch lResult {
                        case let .failure(error):
                            try? queue.tryYield(.failure(error))
                        case let .success(lValue):
                            _ = leftValue.exchange(.init(value: lValue), ordering: .sequentiallyConsistent)
                            guard let rValue = rightValue.load(ordering: .sequentiallyConsistent).value else { return }
                            try? queue.tryYield(.success((lValue, rValue)))
                    }
                    queue.finish()
                }
                let rightCancellable = await right { rResult in
                    switch rResult {
                        case let .failure(error):
                            try? queue.tryYield(.failure(error))
                        case let .success(rValue):
                            _ = rightValue.exchange(.init(value: rValue), ordering: .sequentiallyConsistent)
                            guard let lValue = leftValue.load(ordering: .sequentiallyConsistent).value else { return }
                            try? queue.tryYield(.success((lValue, rValue)))
                    }
                    queue.finish()
                }
                try! resumption.resume()
                await downstream(iterator.next() ?? .failure(CancellationError()))
                try? leftCancellable.cancel()
                try? rightCancellable.cancel()
            },
            onCancel: {
                try? queue.tryYield(.failure(CancellationError()))
            }
        )
    } }
}

public func Anded<Left, Right>(
    _ left: Future<Left>,
    _ right: Future<Right>
) -> Future<(Left, Right)> {
    and(left, right)
}

public extension Future {
    func and<Other>(
        _ other: Future<Other>
    ) -> Future<(Output, Other)> {
        Anded(self, other)
    }
}

public func &&<Left, Right>(
    _ left: Future<Left>,
    _ right: Future<Right>
) -> Future<(Left, Right)> {
    Anded(left, right)
}

public func and<A, B, C>(
    _ one: Future<A>,
    _ two: Future<B>,
    _ three: Future<C>
) -> Future<(A, B, C)> {
    and(and(one, two), three)
        .map { ($0.0.0, $0.0.1, $0.1) }
}

public func and<A, B, C, D>(
    _ one: Future<A>,
    _ two: Future<B>,
    _ three: Future<C>,
    _ four: Future<D>
) -> Future<(A, B, C, D)> {
    and(and(one, two), and(three, four))
        .map { ($0.0.0, $0.0.1, $0.1.0, $0.1.1) }
}

public func and<A, B, C, D, E>(
    _ one: Future<A>,
    _ two: Future<B>,
    _ three: Future<C>,
    _ four: Future<D>,
    _ five: Future<E>
) -> Future<(A, B, C, D, E)> {
    and(and(and(one, two), and(three, four)), five)
        .map { ($0.0.0.0, $0.0.0.1, $0.0.1.0, $0.0.1.1, $0.1) }
}

public func and<A, B, C, D, E, F>(
    _ one: Future<A>,
    _ two: Future<B>,
    _ three: Future<C>,
    _ four: Future<D>,
    _ five: Future<E>,
    _ six: Future<F>
) -> Future<(A, B, C, D, E, F)> {
    and(and(and(one, two), and(three, four)), and(five, six))
        .map { ($0.0.0.0, $0.0.0.1, $0.0.1.0, $0.0.1.1, $0.1.0, $0.1.1) }
}

public func and<A, B, C, D, E, F, G>(
    _ one: Future<A>,
    _ two: Future<B>,
    _ three: Future<C>,
    _ four: Future<D>,
    _ five: Future<E>,
    _ six: Future<F>,
    _ seven: Future<G>
) -> Future<(A, B, C, D, E, F, G)> {
    and(and(and(one, two), and(three, four)), and(and(five, six), seven))
        .map { ($0.0.0.0, $0.0.0.1, $0.0.1.0, $0.0.1.1, $0.1.0.0, $0.1.0.1, $0.1.1) }
}

public func and<A, B, C, D, E, F, G, H>(
    _ one: Future<A>,
    _ two: Future<B>,
    _ three: Future<C>,
    _ four: Future<D>,
    _ five: Future<E>,
    _ six: Future<F>,
    _ seven: Future<G>,
    _ eight: Future<H>
) -> Future<(A, B, C, D, E, F, G, H)> {
    and(
        and(
            and(one, two),
            and(three, four)
        ),
        and(
            and(five, six),
            and(seven, eight)
        )
    ).map { ($0.0.0.0, $0.0.0.1, $0.0.1.0, $0.0.1.1, $0.1.0.0, $0.1.0.1, $0.1.1.0, $0.1.1.1) }
}
