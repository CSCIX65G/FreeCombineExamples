//
//  Channel+Func.swift
//  
//
//  Created by Van Simmons on 11/25/22.
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
public func consume<A, R>(
    _ f: @escaping (A) async throws -> R
) -> (AsyncStream<R>.Continuation) -> (A) async throws -> Void {
    { continuation in { a in switch try await continuation.yield(f(a)) {
        case .enqueued: return
        case .terminated: throw EnqueueError<R>.terminated
        case let .dropped(r): throw EnqueueError.dropped(r)
        @unknown default:
            fatalError("Unimplemented enqueue case")
    } } }
}

extension Queue {
    func consume<A>(
        _ f: @escaping (A) async throws -> Element
    ) -> (A) async throws -> Void {
        self.continuation.consume(f)
    }
    func consume<A>(
        _ f: @escaping (A) async throws -> Element
    ) -> AsyncFunc<A, Void> {
        self.continuation.consume(f)
    }
    func consume<A>(
        _ f: AsyncFunc<A, Element>
    ) -> AsyncFunc<A, Void> {
        self.continuation.consume(f.call)
    }
}

extension AsyncStream.Continuation {
    func consume<A>(
        _ f: @escaping (A) async throws -> Element
    ) -> (A) async throws -> Void {
        { a in switch try await self.yield(f(a)) {
            case .enqueued: return
            case .terminated: throw EnqueueError<A>.terminated
            case let .dropped(r): throw EnqueueError.dropped(r)
            @unknown default:
                fatalError("Unimplemented enqueue case")
        } }
    }

    func consume<A>(
        _ f: @escaping (A) async throws -> Element
    ) -> AsyncFunc<A, Void> {
        .init(self.consume(f))
    }

    func consume<A>(
        _ f: AsyncFunc<A, Element>
    ) -> AsyncFunc<A, Void> {
        .init(self.consume(f.call))
    }
}

extension IdentifiedAsyncFunc {
    func callAsFunction(continuation: AsyncStream<(ObjectIdentifier, R)>.Continuation, value: A) async throws -> Void {
        switch try await continuation.yield((id, f(value))) {
            case .enqueued: return
            case .terminated: throw EnqueueError<R>.terminated
            case let .dropped(r): throw EnqueueError.dropped(r)
            @unknown default:
                fatalError("Unimplemented enqueue case")
        }
    }
    func callAsFunction(continuation: AsyncStream<(ObjectIdentifier, R)>.Continuation) -> (A) async throws -> Void {
        { value in try await self(continuation: continuation, value: value)}
    }
    func callAsFunction(continuation: AsyncStream<(ObjectIdentifier, R)>.Continuation) -> AsyncFunc<A, Void> {
        .init(self.callAsFunction(continuation: continuation))
    }
    func callAsFunction(channel: Queue<(ObjectIdentifier, R)>, value: A) async throws -> Void {
        try await self(continuation: channel.continuation, value: value)
    }
    func callAsFunction(channel: Queue<(ObjectIdentifier, R)>) -> (A) async throws -> Void {
        { value in try await self(continuation: channel.continuation, value: value)}
    }
    func callAsFunction(channel: Queue<(ObjectIdentifier, R)>) -> AsyncFunc<A, Void> {
        .init(self.callAsFunction(continuation: channel.continuation))
    }
}
