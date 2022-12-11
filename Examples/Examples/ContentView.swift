//
//  ContentView.swift
//  Examples
//
//  Created by Van Simmons on 12/11/22.
//

import SwiftUI
import ComposableConcurrency
import ComposableArchitecture

//enum Tab {
//    case core
//    case channel
//    case queue
//    case future
//    case publisher
//}

struct ContentView: View {
    let store: Store<Application.State, Application.Action>
    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            TabView(selection: viewStore.binding(
                get: \.selectedTab,
                send: Application.Action.selectTab
            )) {
                CoreView()
                    .tabItem {
                        Image(systemName: "square.3.layers.3d")
                        Text("Core")
                    }
                    .tag(Application.Tab.core)
                ChannelView()
                    .tabItem {
                        Image(systemName: "fibrechannel")
                        Text("Channel")
                    }
                    .tag(Application.Tab.channel)
                QueueView()
                    .tabItem {
                        Image(systemName: "figure.stand.line.dotted.figure.stand")
                        Text("Queue")
                    }
                    .tag(Application.Tab.queue)
                FutureView()
                    .tabItem {
                        Image(systemName: "timelapse")
                        Text("Future")
                    }
                    .tag(Application.Tab.future)
                PublisherView()
                    .tabItem {
                        Image(systemName: "tray.and.arrow.up.fill")
                        Text("Publisher")
                    }
                    .tag(Application.Tab.publisher)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(
            store: .init(
                initialState: .init(selectedTab: .core),
                reducer: Application()
            )
        )
    }
}
