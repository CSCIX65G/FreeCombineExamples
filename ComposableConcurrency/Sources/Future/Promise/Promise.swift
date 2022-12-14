//
//  Promise.swift
//  UsingFreeCombine
//
//  Created by Van Simmons on 9/5/22.
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

public enum Promises {
    enum Status: UInt8, Equatable, AtomicValue {
        case waiting
        case succeeded
        case failed
    }
}

public final class Promise<Output> {
    private let function: StaticString
    private let file: StaticString
    private let line: UInt

    private let atomicStatus = ManagedAtomic<Promises.Status>(.waiting)
    private let resumption: Resumption<Output>
    public let cancellable: Cancellable<Output>

    public init(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line
    ) async {
        var localCancellable: Cancellable<Output>!
        self.function = function
        self.file = file
        self.line = line
        self.resumption = try! await pause { outer in
            localCancellable = .init(function: function, file: file, line: line) { try await pause(outer.resume) }
        }
        self.cancellable = localCancellable
    }

    public static func promise(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line
    ) -> Uncancellable<Promise<Output>> {
        .init { await .init(function: function, file: file, line: line) }
    }

    deinit {
        guard atomicStatus.load(ordering: .sequentiallyConsistent) != .waiting else {
            assertionFailure("ABORTING DUE TO LEAKED \(type(of: Self.self)) CREATED in \(function) @ \(file): \(line)")
            try? cancel()
            return
        }
        try? cancellable.cancel()
    }

    private func set(status newStatus: Promises.Status) throws -> Resumption<Output> {
        try AsyncResult<Void, Swift.Error>.success(())
            .set(atomic: atomicStatus, from: .waiting, to: newStatus)
            .get()

        return resumption
    }
}

extension Promise: Identifiable {
    public var id: ObjectIdentifier { .init(self) }
}

extension Promise: Equatable {
    public static func == (lhs: Promise<Output>, rhs: Promise<Output>) -> Bool {
        lhs.id == rhs.id
    }
}

extension Promise: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self)
    }
}

public extension Promise {
    var result: AsyncResult<Output, Swift.Error> {
        get async { await cancellable.result }
    }

    var value: Output {
        get async throws { try await cancellable.value  }
    }
}

public extension Promise {
    func cancel() throws {
        try fail(CancellationError())
    }

    func fulfill(_ result: AsyncResult<Output, Swift.Error>) throws {
        switch result {
            case let .success(arg): try succeed(arg)
            case let .failure(error): try fail(error)
        }
    }

    func succeed(_ arg: Output) throws {
        try set(status: .succeeded).resume(returning: arg)
    }

    func fail(_ error: Swift.Error) throws {
        try set(status: .failed).resume(throwing: error)
    }
}

public extension Promise where Output == Void {
    func succeed() throws -> Void {
        try succeed(())
    }
}

public extension Promise {
    var future: Future<Output> {
        .init { resumption, downstream in .init {
            resumption.resume()
            await downstream(self.result)
        } }
    }
}
