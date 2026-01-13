//
//  ContentView.swift
//  NutritionAIApp
//
//  Created by Mordechai Moshin on 1/12/26.
//

import SwiftUI
import NutritionAI

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            CameraView()
                .tabItem {
                    Label("Camera", systemImage: "camera.fill")
                }
                .tag(0)
            
            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.fill")
                }
                .tag(1)
        }
    }
}

#Preview {
    ContentView()
}
