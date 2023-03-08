//
//  OneOf.swift
//  
//
//  Created by Van Simmons on 9/18/22.
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
public enum OneOfTwo<One, Two> {
    case one(One)
    case two(Two)
}
extension OneOfTwo: Sendable
    where One: Sendable,
        Two: Sendable { }

public enum OneOfThree<One, Two, Three> {
    case one(One)
    case two(Two)
    case three(Three)
}
extension OneOfThree: Sendable
    where One: Sendable,
        Two: Sendable,
        Three: Sendable { }

public enum OneOfFour<One, Two, Three, Four> {
    case one(One)
    case two(Two)
    case three(Three)
    case four(Four)
}
extension OneOfFour: Sendable
    where One: Sendable,
        Two: Sendable,
        Three: Sendable,
        Four: Sendable { }

public enum OneOfFive<One, Two, Three, Four, Five> {
    case one(One)
    case two(Two)
    case three(Three)
    case four(Four)
    case five(Five)
}
extension OneOfFive: Sendable
    where One: Sendable,
        Two: Sendable,
        Three: Sendable,
        Four: Sendable,
        Five: Sendable { }

public enum OneOfSix<One, Two, Three, Four, Five, Six> {
    case one(One)
    case two(Two)
    case three(Three)
    case four(Four)
    case five(Five)
    case six(Six)
}
extension OneOfSix: Sendable
    where One: Sendable,
        Two: Sendable,
        Three: Sendable,
        Four: Sendable,
        Five: Sendable,
        Six: Sendable { }

public enum OneOfSeven<One, Two, Three, Four, Five, Six, Seven> {
    case one(One)
    case two(Two)
    case three(Three)
    case four(Four)
    case five(Five)
    case six(Six)
    case seven(Seven)
}
extension OneOfSeven: Sendable
    where One: Sendable,
        Two: Sendable,
        Three: Sendable,
        Four: Sendable,
        Five: Sendable,
        Six: Sendable,
        Seven: Sendable { }

public enum OneOfEight<One, Two, Three, Four, Five, Six, Seven, Eight> {
    case one(One)
    case two(Two)
    case three(Three)
    case four(Four)
    case five(Five)
    case six(Six)
    case seven(Seven)
    case eight(Eight)
}
extension OneOfEight: Sendable
    where One: Sendable,
        Two: Sendable,
        Three: Sendable,
        Four: Sendable,
        Five: Sendable,
        Six: Sendable,
        Seven: Sendable,
        Eight: Sendable { }
