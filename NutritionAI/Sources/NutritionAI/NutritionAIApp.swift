import SwiftUI

#if !TESTING
@main
struct NutritionAIApp: App {
    @StateObject private var authService = AuthService()
    @StateObject private var apiService = APIService()
    
    init() {}
    
    var body: some Scene {
        WindowGroup {
            if authService.isAuthenticated {
                ContentView(apiService: apiService)
                    .environmentObject(authService)
                    .environmentObject(apiService)
                    .onAppear {
                        apiService.authService = authService
                    }
            } else {
                LoginView(apiService: apiService)
                    .environmentObject(authService)
                    .environmentObject(apiService)
                    .onAppear {
                        apiService.authService = authService
                    }
            }
        }
    }
}
#endif

