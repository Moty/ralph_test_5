import SwiftUI
import NutritionAI

struct AppContentView: View {
    @StateObject private var authService = AuthService()
    @State private var apiService: APIService?
    
    var body: some View {
        Group {
            if let apiService = apiService {
                NutritionAI.ContentView(apiService: apiService)
                    .environmentObject(authService)
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if apiService == nil {
                let service = APIService()
                service.authService = authService
                apiService = service
            }
        }
    }
}
