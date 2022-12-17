//
//  Autoconnect.swift
//
//
//  Created by Van Simmons on 6/7/22.
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
public extension Publisher {
    func autoconnect(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        buffering: AsyncStream<Output>.Continuation.BufferingPolicy = .bufferingOldest(1)
    ) async throws -> Self {
        let subject: Subject<Output> = PassthroughSubject()
        let connectable: Connectable<Output> = .init(upstream: self, subject: subject)
        return .init { resumption, downstream in
            Cancellable<Cancellable<Void>> {
                let cancellable = await subject.asyncPublisher.sink(downstream)
                if connectable.cancellable == nil {
                    await connectable.connect()
                    try? connectable.cancellable?.release()
                }
                resumption.resume()
                return cancellable
            }.join()
        }
    }
}
