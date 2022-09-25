//
//  Channel+Folder.swift
//  
//
//  Created by Van Simmons on 9/23/22.
//

public extension Channel {
    func fold<State>(
        onStartup: Resumption<Void>,
        into folder: AsyncFolder<State, Element>
    ) -> AsyncFold<State, Element> {
        .init(onStartup: onStartup, channel: self, folder: folder)
    }
}

public extension Channel {
    func fold<State>(
        into folder: AsyncFolder<State, Element>
    ) async -> AsyncFold<State, Element> {
        await AsyncFold<State, Element>.fold(channel: self, folder: folder)
    }
}
