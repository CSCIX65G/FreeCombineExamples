//
//  Future+Fold.swift
//  
//
//  Created by Van Simmons on 9/13/22.
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
import Queue

public extension Future {
    func fold<Other>(
        futures: [Future<Other>],
        with combiningFunction: @escaping @Sendable (Output, Other) -> Self
    ) -> Self {
        var this = self
        for future in futures {
            this = this.and(future).flatMap(combiningFunction)
        }
        return this
    }
}

public extension AsyncFold {
    var future: Future<State> {
        .init { resumption, downstream in
                .init { await downstream(self.cancellable.result) }
        }
    }
}

