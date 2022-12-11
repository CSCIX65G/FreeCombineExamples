//
//  UnbreakablePromise.swift
//  
//
//  Created by Van Simmons on 9/15/22.
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

public enum UnbreakablePromises {
    public enum Status: UInt8, Equatable, AtomicValue {
        case waiting
        case succeeded
    }
}

public final class UnbreakablePromise<Output> {
    typealias Status = UnbreakablePromises.Status
    private let function: StaticString
    private let file: StaticString
    private let line: UInt

    private let atomicStatus = ManagedAtomic<Status>(.waiting)
    private let resumption: UnfailingResumption<Output>

    public let uncancellable: Uncancellable<Output>

    public init(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line
    ) async {
        self.function = function
        self.file = file
        self.line = line
        var uc: Uncancellable<Output>!
        self.resumption = await unfailingPause { outer in
            uc = .init(function: function, file: file, line: line) { await unfailingPause(outer.resume) }
        }
        self.uncancellable = uc
    }

    var status: Status {
        atomicStatus.load(ordering: .sequentiallyConsistent)
    }

    /*:
     This is similar to how [leaks of NIO EventLoopPromises](https://github.com/apple/swift-nio/blob/48916a49afedec69275b70893c773261fdd2cfde/Sources/NIOCore/EventLoopFuture.swift#L431) are treated
     */
    deinit {
        guard status != .waiting else {
            Assertion.assertionFailure("ABORTING DUE TO LEAKED \(type(of: Self.self)):\(self)  CREATED in \(function) @ \(file): \(line)")
            return
        }
    }

    private func setSucceeded() throws -> UnfailingResumption<Output> {
        let (success, original) = atomicStatus.compareExchange(
            expected: Status.waiting,
            desired: Status.succeeded,
            ordering: .sequentiallyConsistent
        )
        guard success else {
            throw AtomicError.failedTransition(
                from: .waiting,
                to: .succeeded,
                current: original
            )
        }
        return resumption
    }
}

// async variables
public extension UnbreakablePromise {
    var value: Output {
        get async throws { await uncancellable.value  }
    }
}

public extension UnbreakablePromise {
    func succeed(_ arg: Output) throws {
        try setSucceeded().resume(returning: arg)
    }
}

public extension UnbreakablePromise where Output == Void {
    func succeed() throws -> Void {
        try succeed(())
    }
}
