//
//  Resumption.swift
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

enum Resumptions {
    enum Status: UInt8, AtomicValue, Equatable, Sendable {
        case waiting
        case resumed
    }
}

public final class Resumption<Output: Sendable>: @unchecked Sendable {
    typealias Status = Resumptions.Status
    private let function: StaticString
    private let file: StaticString
    private let line: UInt

    private let atomicStatus = ManagedAtomic<Status>(.waiting)
    private let continuation: UnsafeContinuation<Output, Swift.Error>

    private var status: Status {
        atomicStatus.load(ordering: .sequentiallyConsistent)
    }

    private var leakFailureString: String {
        "ABORTING DUE TO LEAKED \(type(of: Self.self)):\(self)  CREATED in \(function) @ \(file): \(line)"
    }

    private var multipleResumeFailureString: String {
        "ABORTING DUE TO PREVIOUS RESUMPTION: \(type(of: Self.self)):\(self)  CREATED in \(function) @ \(file): \(line)"
    }

    public init(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        continuation: UnsafeContinuation<Output, Swift.Error>
    ) {
        self.function = function
        self.file = file
        self.line = line
        self.continuation = continuation
    }

    /*:
     [leaks of NIO EventLoopPromises](https://github.com/apple/swift-nio/blob/48916a49afedec69275b70893c773261fdd2cfde/Sources/NIOCore/EventLoopFuture.swift#L431)
     */
    deinit {
        guard status == .resumed else {
            Assertion.assertionFailure(leakFailureString)
            continuation.resume(throwing: LeakError())
            return
        }
    }

    private func set(status newStatus: Status) -> Result<Void, Swift.Error> {
        Result.success(()).set(atomic: self.atomicStatus, from: .waiting, to: newStatus)
    }

    public func resume(returning output: Output) -> Void {
        do { try tryResume(returning: output) }
        catch { preconditionFailure(multipleResumeFailureString) }
    }

    public func tryResume(returning output: Output) throws -> Void {
        switch set(status: .resumed) {
            case .success: return continuation.resume(returning: output)
            case .failure(let error): throw error
        }
    }

    public func resume(throwing error: Swift.Error) -> Void {
        do { try tryResume(throwing: error) }
        catch { preconditionFailure(multipleResumeFailureString) }
    }

    public func tryResume(throwing error: Swift.Error) throws -> Void {
        switch set(status: .resumed) {
            case .success: return continuation.resume(throwing: error)
            case .failure(let error): throw error
        }
    }
}

public extension Resumption where Output == Void {
    func resume() -> Void {
        resume(returning: ())
    }

    func tryResume() throws -> Void {
        try tryResume(returning: ())
    }
}

extension Resumption: Identifiable {
    public var id: ObjectIdentifier { .init(self) }
}

extension Resumption: Equatable {
    public static func == (lhs: Resumption<Output>, rhs: Resumption<Output>) -> Bool {
        lhs.id == rhs.id
    }
}

extension Resumption: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.id)
    }
}

public func pause<Output>(
    function: StaticString = #function,
    file: StaticString = #file,
    line: UInt = #line,
    for: Output.Type = Output.self,
    _ resumingWith: (Resumption<Output>) -> Void
) async throws -> Output {
    try await withUnsafeThrowingContinuation { resumption in
        resumingWith(
            .init(
                function: function,
                file: file,
                line: line,
                continuation: resumption
            )
        )
    }
}
