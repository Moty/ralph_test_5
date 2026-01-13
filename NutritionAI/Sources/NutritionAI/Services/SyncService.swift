import Foundation

/// Service to sync local meal data with cloud backend (Firestore)
@MainActor
public class SyncService: ObservableObject {
    public static let shared = SyncService()
    
    @Published public var isSyncing = false
    @Published public var lastSyncDate: Date?
    @Published public var syncError: String?
    
    private let storageService = StorageService.shared
    private var apiService: APIService?
    private var authService: AuthService?
    
    private init() {
        // Load last sync date from UserDefaults
        if let timestamp = UserDefaults.standard.object(forKey: "lastSyncDate") as? Date {
            lastSyncDate = timestamp
        }
    }
    
    /// Configure the sync service with API and Auth services
    public func configure(apiService: APIService, authService: AuthService) {
        self.apiService = apiService
        self.authService = authService
    }
    
    /// Fetch all meals from the cloud and sync with local storage
    public func syncFromCloud() async throws {
        guard let apiService = apiService,
              let authService = authService else {
            throw SyncError.notAuthenticated
        }
        
        // Ensure apiService has authService set for auth headers
        if apiService.authService == nil {
            apiService.authService = authService
        }
        
        guard authService.isAuthenticated else {
            throw SyncError.notAuthenticated
        }
        
        guard !isSyncing else {
            throw SyncError.syncInProgress
        }
        
        isSyncing = true
        syncError = nil
        
        defer {
            isSyncing = false
        }
        
        do {
            // Fetch stats which includes all meals
            print("[SyncService] Fetching user stats...")
            let stats = try await apiService.fetchUserStats()
            print("[SyncService] Stats fetched successfully: \(stats.today.count) meals today")
            
            // TODO: Implement full meal sync when backend provides meal list endpoint
            // For now, we just update the sync timestamp
            lastSyncDate = Date()
            UserDefaults.standard.set(lastSyncDate, forKey: "lastSyncDate")
            
        } catch let error as APIError {
            let message: String
            switch error {
            case .unauthorized:
                message = "Session expired. Please login again."
            case .networkError(let underlyingError):
                message = "Network error: \(underlyingError.localizedDescription)"
            case .serverError(let serverMessage):
                message = "Server error: \(serverMessage)"
            case .invalidResponse:
                message = "Invalid response from server"
            default:
                message = "Error: \(error)"
            }
            print("[SyncService] Sync failed: \(message)")
            syncError = message
            throw SyncError.syncFailed(message)
        } catch {
            let message = error.localizedDescription
            print("[SyncService] Sync failed: \(message)")
            syncError = message
            throw SyncError.syncFailed(message)
        }
    }
    
    /// Check if sync is needed (based on last sync time)
    public var needsSync: Bool {
        guard let lastSync = lastSyncDate else { return true }
        // Sync if last sync was more than 1 hour ago
        return Date().timeIntervalSince(lastSync) > 3600
    }
}

public enum SyncError: LocalizedError {
    case notAuthenticated
    case syncInProgress
    case syncFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Please log in to sync your data"
        case .syncInProgress:
            return "Sync is already in progress"
        case .syncFailed(let message):
            return "Sync failed: \(message)"
        }
    }
}
