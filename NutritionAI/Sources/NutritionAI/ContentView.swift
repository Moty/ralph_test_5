import SwiftUI

public struct ContentView: View {
    public init() {}
    
    public var body: some View {
        TabView {
            CameraView()
                .tabItem {
                    Label("Camera", systemImage: "camera.fill")
                }
            
            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.fill")
                }            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }        }
    }
}
