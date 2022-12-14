//
//  Errors.swift
//  
//
//  Created by Van Simmons on 10/8/22.
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

public struct CancellationFailureError: Swift.Error, Sendable, Equatable { }
public struct ReleaseFailureError: Swift.Error, Sendable, Equatable { }

public struct ReleaseError: Swift.Error, Sendable, Equatable { }
public struct LeakError: Swift.Error, Sendable, Equatable { }
public struct TimeoutError: Swift.Error, Sendable, Equatable { }
public struct SynchronizationError: Error { }

public enum AtomicError<R: AtomicValue>: Error {
    case failedTransition(from: R, to: R, current: R)
}

public enum EnqueueError<Element: Sendable>: Error {
    case dropped(Element)
    case terminated
}
