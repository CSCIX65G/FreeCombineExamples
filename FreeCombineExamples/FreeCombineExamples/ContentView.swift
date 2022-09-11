//
//  ContentView.swift
//  FreeCombineExamples
//
//  Created by Van Simmons on 9/11/22.
//

import SwiftUI
import FreeCombine

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
    }
}
