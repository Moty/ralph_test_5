import SwiftUI

#if !TESTING
@main
struct NutritionAIApp: App {
    @StateObject private var authService = AuthService()
    private let apiService = APIService()
    
    init() {
        apiService.authService = authService
    }
    
    var body: some Scene {
        WindowGroup {
            if authService.isAuthenticated {
                ContentView(apiService: apiService)
                    .environmentObject(authService)
            } else {
                LoginView(apiService: apiService)
                    .environmentObject(authService)
            }
        }
    }
}
#endif

