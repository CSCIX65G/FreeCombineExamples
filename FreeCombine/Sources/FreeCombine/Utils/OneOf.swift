//
//  OneOf.swift
//  
//
//  Created by Van Simmons on 9/18/22.
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
