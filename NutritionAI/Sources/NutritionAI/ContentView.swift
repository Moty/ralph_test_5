import SwiftUI

public struct ContentView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var themeManager = ThemeManager.shared
    @State private var selectedTab = 0
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var showOnboarding = false
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
                        GuestModeCard {
                            authService.logout()
                        }
                    }
                    
                    TabView(selection: $selectedTab) {
                        HomeView(selectedTab: $selectedTab, apiService: apiService)
                            .tabItem {
                                Label("Home", systemImage: "house.fill")
                            }
                            .tag(0)

                        // Progress tab for registered users only
                        if authService.isRegisteredUser {
                            DietProgressView(apiService: apiService)
                                .tabItem {
                                    Label("Progress", systemImage: "chart.line.uptrend.xyaxis")
                                }
                                .tag(1)
                        }

                        CameraView(apiService: apiService)
                            .tabItem {
                                Label("Camera", systemImage: "camera.fill")
                            }
                            .tag(authService.isRegisteredUser ? 2 : 1)

                        // History only available for registered users
                        if authService.isRegisteredUser {
                            HistoryView(apiService: apiService)
                                .tabItem {
                                    Label("History", systemImage: "clock.fill")
                                }
                                .tag(3)
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
                            .tag(authService.isRegisteredUser ? 4 : 3)
                    }
                    .tint(AppColors.primaryGradientEnd)
                }
            } else {
                LoginView(apiService: apiService)
            }
        }
        .onAppear {
            if !hasSeenOnboarding {
                showOnboarding = true
            }
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView {
                hasSeenOnboarding = true
                showOnboarding = false
            }
        }
        .preferredColorScheme(themeManager.colorScheme)
    }
}
