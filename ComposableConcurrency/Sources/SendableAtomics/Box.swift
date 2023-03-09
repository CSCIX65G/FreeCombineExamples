//
//  ValueRef.swift
//
//
//  Created by Van Simmons on 5/18/22.
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

public final class Box<Value> {
    public let value: Value
    public init(value: Value) { self.value = value }
}

extension Box: AtomicReference { }
extension Box: Sendable where Value: Sendable { }

extension Box: Identifiable {
    public var id: ObjectIdentifier { ObjectIdentifier(self) }
}

extension Box: Equatable {
    public static func == (lhs: Box<Value>, rhs: Box<Value>) -> Bool {
        lhs.id == rhs.id
    }
}

extension Box: Hashable {
    public func hash(into hasher: inout Hasher) {
        id.hash(into: &hasher)
    }
}

public final class MutableBox<Value> {
    public private(set) var value: Value
    public init(value: Value) { self.value = value }
}

public extension MutableBox {
    @discardableResult
    func set(value: Value) -> Value {
        let tmp = self.value
        self.value = value
        return tmp
    }

    @discardableResult
    func set(value: () async -> Value) async -> Value {
        let tmp = self.value
        self.value = await value()
        return tmp
    }

    func set<Tail>(keyPath: WritableKeyPath<Value, Tail>, to newValue: Tail) async -> Void {
        self.value[keyPath: keyPath] = newValue
    }
}

extension MutableBox: AtomicReference { }

extension MutableBox {
    public func append<T>(_ t: T) throws -> Void where Value == [T] {
        value.append(t)
    }
}
