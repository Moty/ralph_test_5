import SwiftUI

public struct ContentView: View {
    @EnvironmentObject var authService: AuthService
    @State private var selectedTab = 0
    let apiService: APIService
    
    public init(apiService: APIService) {
        self.apiService = apiService
    }
    
    public var body: some View {
        Group {
            if authService.isAuthenticated {
                TabView(selection: $selectedTab) {
                    HomeView(selectedTab: $selectedTab, apiService: apiService)
                        .tabItem {
                            Label("Home", systemImage: "house.fill")
                        }
                        .tag(0)
                    
                    CameraView(apiService: apiService)
                        .tabItem {
                            Label("Camera", systemImage: "camera.fill")
                        }
                        .tag(1)
                    
                    HistoryView()
                        .tabItem {
                            Label("History", systemImage: "clock.fill")
                        }
                        .tag(2)
                    
                    SettingsView()
                        .tabItem {
                            Label("Settings", systemImage: "gear")
                        }
                        .tag(3)
                }
            } else {
                LoginView(apiService: apiService)
            }
        }
    }
}
