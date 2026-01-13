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
    
    // Available Gemini models that support vision
    let availableModels = [
        "gemini-2.5-flash",
        "gemini-2.5-pro",
        "gemini-2.0-flash",
        "gemini-2.0-flash-exp"
    ]
    
    private init() {
        // Default to Cloud Run production URL
        self.backendURL = UserDefaults.standard.string(forKey: "backendURL") ?? "https://nutrition-ai-backend-1051629517898.us-central1.run.app"
        self.geminiModel = UserDefaults.standard.string(forKey: "geminiModel") ?? "gemini-2.5-flash"
    }
    
    func resetToDefault() {
        backendURL = "https://nutrition-ai-backend-1051629517898.us-central1.run.app"
        geminiModel = "gemini-2.5-flash"
    }
    
    func setLocalhost() {
        backendURL = "http://localhost:3000"
    }
}
