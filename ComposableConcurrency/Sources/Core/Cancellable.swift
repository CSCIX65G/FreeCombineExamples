//
//  Cancellable.swift
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
@preconcurrency import Atomics

public enum Cancellables {
    @TaskLocal public static var status = ManagedAtomic<Status>(.running)

    @inlinable
    public static var isCancelled: Bool {
        status.load(ordering: .relaxed) == .cancelled
    }

    @inlinable
    public static func checkCancellation() throws -> Void {
        guard !isCancelled else { throw CancellationError() }
    }

    public enum Status: UInt8, Sendable, AtomicValue, Equatable {
        case running
        case finished
        case cancelled
        case released
    }
}

public final class Cancellable<Output: Sendable>: Sendable {
    typealias Status = Cancellables.Status

    private let function: StaticString
    private let file: StaticString
    private let line: UInt

    private let task: Task<Output, Swift.Error>
    private let atomicStatus = ManagedAtomic<Status>(.running)

    private var status: Status {
        atomicStatus.load(ordering: .relaxed)
    }

    private var leakFailureString: String {
        "ABORTING DUE TO LEAKED \(type(of: Self.self)):\(self)  CREATED in \(function) @ \(file): \(line)"
    }

    public init(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        operation: @escaping @Sendable () async throws -> Output
    ) {
        self.function = function
        self.file = file
        self.line = line
        let atomic = atomicStatus
        self.task = .init {
            try await Cancellables.$status.withValue(atomic) {
                try await AsyncResult(catching: operation)
                    .set(atomic: atomic, from: .running, to: .finished)
                    .mapError {
                        guard let err = $0 as? AtomicError<Status>, case .failedTransition(_, _, .cancelled) = err else {
                            return $0
                        }
                        return CancellationError()
                    }
                    .get()
            }
        }
    }
    
    @Sendable public func cancel() throws {
        try AsyncResult<Void, Swift.Error>.success(())
            .set(atomic: atomicStatus, from: Status.running, to: Status.cancelled)
            .mapError {_ in CancellationFailureError() }
            .get()
        // Allow the task cancellation handlers to run
        // These are opaque so we can't replace them with wrappers
        task.cancel()
    }

    public var value: Output {
        get async throws { try await task.value }
    }
    public var result: AsyncResult<Output, Swift.Error> {
        get async { await .init(task.result) }
    }

    /*:
     [leaks of NIO EventLoopPromises](https://github.com/apple/swift-nio/blob/48916a49afedec69275b70893c773261fdd2cfde/Sources/NIOCore/EventLoopFuture.swift#L431)
     are dealt with in the same way.  We want to do the same.
     */
    deinit {
        guard status != Status.running else {
            Assertion.assertionFailure(leakFailureString)
            try? cancel()
            return
        }
    }
}

extension Cancellable where Output == Void {
    @Sendable public func release() throws {
        try AsyncResult<Void, Swift.Error>.success(())
            .set(atomic: atomicStatus, from: Status.running, to: Status.released)
            .mapError {_ in CancellationFailureError() }
            .get()
    }
}

extension Cancellable: Identifiable {
    public var id: ObjectIdentifier { ObjectIdentifier(self) }
}

extension Cancellable: AtomicReference { }
