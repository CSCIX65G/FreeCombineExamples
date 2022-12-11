//
//  Future+Publisher.swift
//
//
//  Created by Van Simmons on 7/10/22.
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
import Future

public extension Future {
    var publisher: Publisher<Output> {
        .init { resumption, downstream in
            self(onStartup: resumption) { result in
                switch result {
                    case let .success(value):
                        do { try await downstream(.value(value)) }
                        catch { return }
                    case let .failure(error):
                        _ = try? await downstream(.completion(.failure(error)))
                        return
                }
                try? await downstream(.completion(.finished))
            }
        }
    }
}
