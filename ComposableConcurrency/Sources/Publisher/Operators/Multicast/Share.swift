//
//  Share.swift
//
//
//  Created by Van Simmons on 6/26/22.
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
    func share() async throws -> Self {
        let subject: Subject<Output> = PassthroughSubject()
        let upstreamBox: MutableBox<Cancellable<Void>?> = .init(value: .none)
        return .init { resumption, downstream in
            Cancellable<Cancellable<Void>> {
                let cancellable = await subject.asyncPublisher.sink(downstream)
                if  upstreamBox.value == nil {
                    let upstream = await self.sink(subject.send)
                    try? upstream.release()
                    upstreamBox.set(value: upstream)
                }
                resumption.resume()
                return cancellable
            }.join()
        }
    }
}
