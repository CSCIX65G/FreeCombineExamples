//
//  Utils.swift
//
//
//  Created by Van Simmons on 5/28/22.
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
@Sendable public func void0() -> Void { }
@Sendable public func void1<T>(_ t: T) -> Void { }
@Sendable public func void2<T, U>(_ t: T, _ u: U) -> Void { }
@Sendable public func identity<T>(_ t: T) -> T { return t }

precedencegroup CompositionPrecedence {
  associativity: right
  higherThan: ApplicationPrecedence
  lowerThan: MultiplicationPrecedence, AdditionPrecedence
}

precedencegroup ApplicationPrecedence {
  associativity: right
  higherThan: AssignmentPrecedence
  lowerThan: MultiplicationPrecedence, AdditionPrecedence
}

infix operator |>: ApplicationPrecedence  // apply
infix operator >>>: CompositionPrecedence // compose
infix operator >>=: CompositionPrecedence // bind
infix operator <*>: CompositionPrecedence // zip

public func |> <A, B>(
    a: A,
    f: @escaping (A) async -> B
) async -> B {
    await f(a)
}

public func >>> <A, B, C>(
    f: @escaping (A) async -> B,
    g: @escaping (B) async -> C
) -> (A) async -> C {
    { await g(f($0)) }
}

public func >>=<A, B, C>(
    _ f: @escaping (A) async -> B,
    _ g: @escaping (B) async -> (A) async -> C
) -> (A) async -> C {
    { a in await a |> a |> f >>> g }
}

public func >>=<A, B, C>(
    _ f: @escaping (A) async throws -> B,
    _ g: @escaping (B, A) async -> C
) -> (A) async -> C {
    { a in try! await g(f(a), a) }
}

func <*><A, B, C>(
    _ z1: @escaping (A) -> B,
    _ z2: @escaping (A) -> C
) -> (A) -> (B, C) {
    { a in (z1(a), z2(a)) }
}

func fork<A, B>(
    _ f: @Sendable @escaping (A) async -> B
) -> @Sendable (A) -> Uncancellable<B> {
    { a in  Uncancellable { await f(a) } }
}

func fork<A, B>(
    _ f: @Sendable @escaping (A) async throws -> B
) -> @Sendable (A) -> Cancellable<B> {
    { a in  Cancellable { try await f(a) } }
}

func join<A, B>(
    _ f: @Sendable @escaping (A) async -> Uncancellable<B>
) -> (A) async -> B {
    { a in await f(a).value }
}

func join<A, B>(
    _ f: @Sendable @escaping (A) async throws -> Cancellable<B>
) -> @Sendable (A) async throws -> B {
    { a in try await f(a).value }
}

func coalesceEffects<A, B, C>(
    _ f: @Sendable @escaping (A) async throws -> (B) async throws -> C
) -> @Sendable (A) -> (B) async throws -> C {
    { a in { b in try await f(a)(b) } }
}

func coalesceEffects<A, B, C>(
    _ f: @Sendable @escaping (A) throws -> (B) throws -> C
) -> @Sendable (A) -> (B) throws -> C {
    { a in { b in try f(a)(b) } }
}

func coalesceEffects<A, B, C>(
    _ f: @Sendable @escaping (A) async -> (B) async -> C
) -> @Sendable (A) -> (B) async -> C {
    { a in { b in await f(a)(b) } }
}
