//
//  ExamplesApp.swift
//  Examples
//
//  Created by Van Simmons on 12/11/22.
//

import SwiftUI
import ComposableArchitecture

@main
struct ExamplesApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView(
                store: .init(
                    initialState: .init(selectedTab: .core),
                    reducer: Application()
                )
            )
        }
    }
}
