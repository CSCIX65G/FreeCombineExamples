//
//  Assertion.swift
//
//
//  Created by Van Simmons on 8/28/22.
//
public enum Assertion { }

extension Assertion {
    static var runningTests = false

    public static func assert(
        _ condition: @autoclosure () -> Bool,
        _ message: @autoclosure () -> String = String(),
        file: StaticString = #file,
        line: UInt = #line
    ) {
        if !runningTests {
            Swift.assert(condition(), message(), file: file, line: line)
        }
    }

    public static func assertionFailure(
        _ message: @autoclosure () -> String = String(),
        file: StaticString = #file,
        line: UInt = #line
    ) {
        if !runningTests {
            Swift.assertionFailure(message(), file: file, line: line)
        }
    }
}

