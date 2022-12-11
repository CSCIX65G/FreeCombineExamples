//
//  ApplicationReducer.swift
//  Examples
//
//  Created by Van Simmons on 12/11/22.
//

import ComposableArchitecture

struct Application: ReducerProtocol {
    enum Tab {
        case core
        case channel
        case queue
        case future
        case publisher
    }

    struct State: Equatable {
        var selectedTab: Tab
    }

    enum Action {
        case selectTab(Tab)
    }

    func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
        switch action {
            case let .selectTab(tab):
                state.selectedTab = tab
                return .none
        }
    }
}
