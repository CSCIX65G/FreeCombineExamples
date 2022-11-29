//
//  Channel+Folder.swift
//  
//
//  Created by Van Simmons on 9/23/22.
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
public extension Queue {
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

public extension Queue {
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
