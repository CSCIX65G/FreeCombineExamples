//
//  Zipped.swift
//  
//
//  Created by Van Simmons on 10/28/22.
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
    func zip<Other>(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        _ other: Publisher<Other>
    ) -> Publisher<(Output, Other)> {
        Zipped(function: function, file: file, line: line, self, other)
    }
}

public func Zipped<Left, Right>(
    function: StaticString = #function,
    file: StaticString = #file,
    line: UInt = #line,
    _ left: Publisher<Left>,
    _ right: Publisher<Right>
) -> Publisher<(Left, Right)> {
    zip(function: function, file: file, line: line, left, right)
}

public func zip<Left, Right>(
    function: StaticString = #function,
    file: StaticString = #file,
    line: UInt = #line,
    _ left: Publisher<Left>,
    _ right: Publisher<Right>
) -> Publisher<(Left, Right)> {
    .init { resumption, downstream in
        let cancellable = Queue<Zip<Left, Right>.Action>(buffering: .bufferingOldest(2))
            .fold(
                function: function,
                file: file,
                line: line,
                onStartup: resumption,
                into: Zip<Left, Right>.folder(
                    left: left,
                    right: right,
                    downstream: downstream
                )
            )
            .cancellable
        return .init(function: function, file: file, line: line) {
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

public func zip<A, B, C>(
    function: StaticString = #function,
    file: StaticString = #file,
    line: UInt = #line,
    _ one: Publisher<A>,
    _ two: Publisher<B>,
    _ three: Publisher<C>
) -> Publisher<(A, B, C)> {
    zip(
        function: function, file: file, line: line,
        zip(function: function, file: file, line: line, one, two),
        three
    )
    .map {
        ($0.0.0, $0.0.1, $0.1)
    }
}

public func zip<A, B, C, D>(
    function: StaticString = #function,
    file: StaticString = #file,
    line: UInt = #line,
    _ one: Publisher<A>,
    _ two: Publisher<B>,
    _ three: Publisher<C>,
    _ four: Publisher<D>
) -> Publisher<(A, B, C, D)> {
    zip(
        function: function, file: file, line: line,
        zip(function: function, file: file, line: line, one, two),
        zip(function: function, file: file, line: line, three, four)
    )
    .map {
        ($0.0.0, $0.0.1, $0.1.0, $0.1.1)
    }
}

public func zip<A, B, C, D, E>(
    function: StaticString = #function,
    file: StaticString = #file,
    line: UInt = #line,
    _ one: Publisher<A>,
    _ two: Publisher<B>,
    _ three: Publisher<C>,
    _ four: Publisher<D>,
    _ five: Publisher<E>
) -> Publisher<(A, B, C, D, E)> {
    zip(
        function: function, file: file, line: line,
        zip(
            function: function, file: file, line: line,
            zip(function: function, file: file, line: line, one, two),
            zip(function: function, file: file, line: line, three, four)
        ),
        five
    )
    .map {
        ($0.0.0.0, $0.0.0.1, $0.0.1.0, $0.0.1.1, $0.1)
    }
}

public func zip<A, B, C, D, E, F>(
    function: StaticString = #function,
    file: StaticString = #file,
    line: UInt = #line,
    _ one: Publisher<A>,
    _ two: Publisher<B>,
    _ three: Publisher<C>,
    _ four: Publisher<D>,
    _ five: Publisher<E>,
    _ six: Publisher<F>
) -> Publisher<(A, B, C, D, E, F)> {
    zip(
        function: function, file: file, line: line,
        zip(
            function: function, file: file, line: line,
            zip(function: function, file: file, line: line, one, two),
            zip(function: function, file: file, line: line, three, four)
        ),
        zip(function: function, file: file, line: line, five, six)
    )
    .map {
        ($0.0.0.0, $0.0.0.1, $0.0.1.0, $0.0.1.1, $0.1.0, $0.1.1)
    }
}

public func zip<A, B, C, D, E, F, G>(
    function: StaticString = #function,
    file: StaticString = #file,
    line: UInt = #line,
    _ one: Publisher<A>,
    _ two: Publisher<B>,
    _ three: Publisher<C>,
    _ four: Publisher<D>,
    _ five: Publisher<E>,
    _ six: Publisher<F>,
    _ seven: Publisher<G>
) -> Publisher<(A, B, C, D, E, F, G)> {
    zip(
        function: function, file: file, line: line,
        zip(
            function: function, file: file, line: line,
            zip(function: function, file: file, line: line, one, two),
            zip(function: function, file: file, line: line, three, four)
        ),
        zip(
            function: function, file: file, line: line,
            zip(function: function, file: file, line: line, five, six),
            seven
        )
    )
    .map { ($0.0.0.0, $0.0.0.1, $0.0.1.0, $0.0.1.1, $0.1.0.0, $0.1.0.1, $0.1.1) }
}

public func zip<A, B, C, D, E, F, G, H>(
    function: StaticString = #function,
    file: StaticString = #file,
    line: UInt = #line,
    _ one: Publisher<A>,
    _ two: Publisher<B>,
    _ three: Publisher<C>,
    _ four: Publisher<D>,
    _ five: Publisher<E>,
    _ six: Publisher<F>,
    _ seven: Publisher<G>,
    _ eight: Publisher<H>
) -> Publisher<(A, B, C, D, E, F, G, H)> {
    zip(
        function: function, file: file, line: line,
        zip(
            function: function, file: file, line: line,
            zip(function: function, file: file, line: line, one, two),
            zip(function: function, file: file, line: line, three, four)
        ),
        zip(
            function: function, file: file, line: line,
            zip(function: function, file: file, line: line, five, six),
            zip(function: function, file: file, line: line, seven, eight)
        )
    ).map {
        ($0.0.0.0, $0.0.0.1, $0.0.1.0, $0.0.1.1, $0.1.0.0, $0.1.0.1, $0.1.1.0, $0.1.1.1)
    }
}
