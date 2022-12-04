//
//  Future+Value.swift
//  
//
//  Created by Van Simmons on 10/14/22.
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

extension Future {
    var value: Output {
        get async throws { try await futureValue.value }
    }

    var result: Result<Output, Swift.Error> {
        get async { await futureValue.result }
    }

    var futureValue: Cancellable<Output> {
        get {
            .init {
                let ref: MutableBox<Result<Output, Swift.Error>?> = .init(value: .none)
                let z: Cancellable<Void> = await self.sink { ref.set(value: $0) }
                return try await withTaskCancellationHandler(
                    operation: {
                        _ = await z.result
                        return try ref.value!.get()
                    },
                    onCancel: {  try? z.cancel() }
                )
            }
        }
    }
}
