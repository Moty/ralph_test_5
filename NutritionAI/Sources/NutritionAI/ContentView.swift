import SwiftUI

public struct ContentView: View {
    @EnvironmentObject var authService: AuthService
    @State private var selectedTab = 0
    let apiService: APIService
    
    public init(apiService: APIService) {
        self.apiService = apiService
        
        // Customize TabBar appearance
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemBackground
        
        // Selected tab color
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(AppColors.primaryGradientEnd)
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(AppColors.primaryGradientEnd)]
        
        // Normal tab color
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor.secondaryLabel
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.secondaryLabel]
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    public var body: some View {
        Group {
            if authService.isAuthenticated {
                VStack(spacing: 0) {
                    // Guest mode banner
                    if authService.isGuest {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Guest Mode – Data stored locally only")
                                .font(.caption)
                                .fontWeight(.medium)
                            Spacer()
                            Button("Sign Up") {
                                authService.logout() // Go back to login screen
                            }
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(AppColors.primaryGradientEnd)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.orange.opacity(0.15))
                    }
                    
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
                        
                        // History only available for registered users
                        if authService.isRegisteredUser {
                            HistoryView()
                                .tabItem {
                                    Label("History", systemImage: "clock.fill")
                                }
                                .tag(2)
                        } else {
                            GuestHistoryView()
                                .tabItem {
                                    Label("History", systemImage: "clock.fill")
                                }
                                .tag(2)
                        }
                        
                        SettingsView(apiService: apiService)
                            .tabItem {
                                Label("Settings", systemImage: "gear")
                            }
                            .tag(3)
                    }
                    .tint(AppColors.primaryGradientEnd)
                }
            } else {
                LoginView(apiService: apiService)
            }
        }
    }
}
