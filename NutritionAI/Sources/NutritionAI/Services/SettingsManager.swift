import Foundation

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    @Published var backendURL: String {
        didSet {
            UserDefaults.standard.set(backendURL, forKey: "backendURL")
        }
    }
    
    @Published var geminiModel: String {
        didSet {
            UserDefaults.standard.set(geminiModel, forKey: "geminiModel")
        }
    }
    
    // Available Gemini models that support vision (ordered by quota availability)
    let availableModels = [
        "gemini-2.0-flash",        // Unlimited RPD - RECOMMENDED
        "gemini-2.0-flash-lite",   // Unlimited RPD - Fast & light
        "gemini-2.5-flash-lite",   // Unlimited RPD - Good balance
        "gemini-3-flash",          // 10K RPD - Newest
        "gemini-2.5-flash",        // 10K RPD
        "gemini-2.5-pro",          // 10K RPD - Best quality
        "gemini-3-pro"             // 250 RPD - Highest quality
    ]
    
    private init() {
        // Default to Cloud Run production URL
        self.backendURL = UserDefaults.standard.string(forKey: "backendURL") ?? "https://nutrition-ai-backend-1051629517898.us-central1.run.app"
        self.geminiModel = UserDefaults.standard.string(forKey: "geminiModel") ?? "gemini-2.0-flash"
    }
    
    func resetToDefault() {
        backendURL = "https://nutrition-ai-backend-1051629517898.us-central1.run.app"
        geminiModel = "gemini-2.0-flash"
    }
    
    func setLocalhost() {
        backendURL = "http://localhost:3000"
    }
}
