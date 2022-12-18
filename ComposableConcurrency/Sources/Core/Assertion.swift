//
//  Assertion.swift
//
//
//  Created by Van Simmons on 8/28/22.
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
public enum Assertion { }

extension Assertion {
    static var runningTests = false

    public static func assert(
        file: StaticString = #file,
        line: UInt = #line,
        _ condition: @autoclosure () -> Bool,
        _ message: @autoclosure () -> String = String()
    ) {
        if !runningTests {
            Swift.assert(condition(), message(), file: file, line: line)
        }
    }

    public static func assertionFailure(
        file: StaticString = #file,
        line: UInt = #line,
        _ message: @autoclosure () -> String = String()
    ) {
        if !runningTests {
            Swift.assertionFailure(message(), file: file, line: line)
        }
    }
}

