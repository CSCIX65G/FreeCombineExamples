//
//  Channel+Future.swift
//
//
//  Created by Van Simmons on 9/2/22.
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

public extension Queue {
    @Sendable func consume<Upstream: Sendable>(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        future: Future<Upstream>,
        using action: @Sendable @escaping (AsyncResult<Upstream, Swift.Error>) -> Element
    ) async -> Cancellable<Void>  {
        await future {
            guard !Cancellables.isCancelled else { return }
            try? self.tryYield(action($0))
        }
    }
}

public extension AsyncStream.Continuation {
    func consume<Upstream: Sendable>(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        future: Future<Upstream>,
        using action: @Sendable @escaping (AsyncResult<Upstream, Swift.Error>) -> Element
    ) async -> Cancellable<Void> where AsyncStream.Element == Sendable {
        await future {
            guard !Cancellables.isCancelled else { return }
            try? self.tryYield(action($0))
        }
    }
}
