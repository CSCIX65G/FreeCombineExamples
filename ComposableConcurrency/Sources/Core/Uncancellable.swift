//
//  Uncancellable.swift
//
//
//  Created by Van Simmons on 9/7/22.
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

public enum Uncancellables {
    enum Status: UInt8, Sendable, AtomicValue, Equatable {
        case running
        case finished
        case released
    }
}

extension ManagedAtomic: @unchecked Sendable { }

public final class Uncancellable<Output: Sendable>: @unchecked Sendable {
    typealias Status = Uncancellables.Status
    private let function: StaticString
    private let file: StaticString
    private let line: UInt

    private let task: Task<Output, Never>
    private let atomicStatus = ManagedAtomic<Status>(.running)

    private var status: Status {
        atomicStatus.load(ordering: .sequentiallyConsistent)
    }

    private var leakFailureString: String {
        "ABORTING DUE TO LEAKED \(type(of: Self.self)):\(self)  CREATED in \(function) @ \(file): \(line)"
    }

    public init(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        released: Bool = false,
        operation: @Sendable @escaping () async -> Output
    ) {
        self.function = function
        self.file = file
        self.line = line

        atomicStatus.store(released ? .released : .running, ordering: .sequentiallyConsistent)
        let atomic = atomicStatus
        self.task = .init {
            let retValue = await operation()
            (_, _) = atomic.compareExchange(expected: .running, desired: .finished, ordering: .sequentiallyConsistent)
            return retValue
        }
    }

    @Sendable public func release() throws {
        try AsyncResult<Void, Swift.Error>.success(())
            .set(atomic: atomicStatus, from: Status.running, to: Status.released)
            .mapError {_ in ReleasedError() }
            .get()
    }

    /*:
     [leaks of NIO EventLoopPromises](https://github.com/apple/swift-nio/blob/48916a49afedec69275b70893c773261fdd2cfde/Sources/NIOCore/EventLoopFuture.swift#L431)
     */
    deinit {
        guard status != .running else {
            Assertion.assertionFailure(leakFailureString)
            return
        }
    }

    public var value: Output {
        get async { await task.value }
    }
}

extension Uncancellable: Identifiable {
    public var id: ObjectIdentifier { ObjectIdentifier(self) }
}
