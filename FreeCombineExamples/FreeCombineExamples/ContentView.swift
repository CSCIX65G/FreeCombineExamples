//
//  ContentView.swift
//  FreeCombineExamples
//
//  Created by Van Simmons on 8/27/22.
//

import SwiftUI
import FreeCombine
import Atomics

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundColor(.accentColor)
            Text("Hello, world!")
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .previewLayout(.sizeThatFits)
    }
}
