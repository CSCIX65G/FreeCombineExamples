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

public enum OneOfThree<One, Two, Three> {
    case one(One)
    case two(Two)
    case three(Three)
}

public enum OneOfFour<One, Two, Three, Four> {
    case one(One)
    case two(Two)
    case three(Three)
    case four(Four)
}

public enum OneOfFive<One, Two, Three, Four, Five> {
    case one(One)
    case two(Two)
    case three(Three)
    case four(Four)
    case five(Five)
}

public enum OneOfSix<One, Two, Three, Four, Five, Six> {
    case one(One)
    case two(Two)
    case three(Three)
    case four(Four)
    case five(Five)
    case six(Six)
}

public enum OneOfSeven<One, Two, Three, Four, Five, Six, Seven> {
    case one(One)
    case two(Two)
    case three(Three)
    case four(Four)
    case five(Five)
    case six(Six)
    case seven(Seven)
}

public enum OneOfEight<One: Sendable, Two: Sendable, Three: Sendable, Four: Sendable, Five: Sendable, Six: Sendable, Seven: Sendable, Eight: Sendable>: Sendable {
    case one(One)
    case two(Two)
    case three(Three)
    case four(Four)
    case five(Five)
    case six(Six)
    case seven(Seven)
    case eight(Eight)
}
