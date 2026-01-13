import Foundation
import Security

@MainActor
public class AuthService: ObservableObject {
    @Published public var isAuthenticated = false
    @Published public var currentUser: User?
    
    private let keychainService = "com.nutritionai.app"
    private let tokenKey = "jwt_token"
    
    public init() {
        checkAuthentication()
    }
    
    func login(token: String, user: User) {
        saveToken(token)
        currentUser = user
        isAuthenticated = true
    }
    
    func register(token: String, user: User) {
        saveToken(token)
        currentUser = user
        isAuthenticated = true
    }
    
    func logout() {
        deleteToken()
        currentUser = nil
        isAuthenticated = false
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
    
    private func checkAuthentication() {
        if let token = getToken(), !token.isEmpty {
            isAuthenticated = true
        }
    }
}
