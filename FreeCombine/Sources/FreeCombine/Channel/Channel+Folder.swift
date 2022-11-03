//
//  Channel+Folder.swift
//  
//
//  Created by Van Simmons on 9/23/22.
//

public extension Channel {
    func fold<State>(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        onStartup: Resumption<Void>? = .none,
        into folder: AsyncFolder<State, Element>
    ) -> AsyncFold<State, Element> {
        .init(
            function: function,
            file: file,
            line: line,
            onStartup: onStartup,
            channel: self,
            folder: folder
        )
    }
}

public extension Channel {
    func fold<State>(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        into folder: AsyncFolder<State, Element>
    ) async -> AsyncFold<State, Element> {
        await AsyncFold<State, Element>.fold(
            function: function,
            file: file,
            line: line,
            channel: self,
            folder: folder
        )
    }
}
