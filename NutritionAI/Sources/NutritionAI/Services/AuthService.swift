import Foundation
import Security

@MainActor
public class AuthService: ObservableObject {
    @Published public var isAuthenticated = false
    @Published public var isGuest = false
    @Published public var currentUser: User?
    
    private let keychainService = "com.nutritionai.app"
    private let tokenKey = "jwt_token"
    private let userKey = "user_data"
    
    public init() {
        restoreSession()
    }
    
    /// Check if the user is a registered user (not guest)
    public var isRegisteredUser: Bool {
        return isAuthenticated && !isGuest && currentUser != nil
    }
    
    func login(token: String, user: User) {
        saveToken(token)
        saveUser(user)
        currentUser = user
        isAuthenticated = true
        isGuest = false
    }
    
    func register(token: String, user: User) {
        saveToken(token)
        saveUser(user)
        currentUser = user
        isAuthenticated = true
        isGuest = false
    }
    
    /// Continue as guest - data stored locally only
    func continueAsGuest() {
        print("[AuthService] continueAsGuest called")
        // Clear any stored credentials first
        deleteToken()
        deleteUser()
        // Then update state
        currentUser = nil
        isGuest = true
        isAuthenticated = true
        // Explicitly notify observers
        objectWillChange.send()
        print("[AuthService] Guest mode activated - isAuthenticated: \(isAuthenticated), isGuest: \(isGuest)")
    }
    
    func logout() {
        deleteToken()
        deleteUser()
        currentUser = nil
        isAuthenticated = false
        isGuest = false
    }
    
    func getToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: tokenKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return token
    }
    
    private func saveToken(_ token: String) {
        guard let data = token.data(using: .utf8) else { return }
        
        // Delete any existing token first
        deleteToken()
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: tokenKey,
            kSecValueData as String: data
        ]
        
        SecItemAdd(query as CFDictionary, nil)
    }
    
    private func deleteToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: tokenKey
        ]
        
        SecItemDelete(query as CFDictionary)
    }
    
    private func saveUser(_ user: User) {
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: userKey)
        }
    }
    
    private func loadUser() -> User? {
        guard let data = UserDefaults.standard.data(forKey: userKey),
              let user = try? JSONDecoder().decode(User.self, from: data) else {
            return nil
        }
        return user
    }
    
    private func deleteUser() {
        UserDefaults.standard.removeObject(forKey: userKey)
    }
    
    private func restoreSession() {
        // Check if we have a saved token and user
        if let token = getToken(), !token.isEmpty, let user = loadUser() {
            currentUser = user
            isAuthenticated = true
            isGuest = false
            print("[AuthService] Restored session for user: \(user.email)")
        } else {
            isAuthenticated = false
            isGuest = false
            currentUser = nil
            print("[AuthService] No saved session found")
        }
    }
}
