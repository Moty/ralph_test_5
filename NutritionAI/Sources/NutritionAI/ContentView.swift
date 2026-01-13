import SwiftUI

public struct ContentView: View {
    let apiService: APIService
    
    public init(apiService: APIService) {
        self.apiService = apiService
    }
    
    public var body: some View {
        TabView {
            HomeView(apiService: apiService)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
            
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
