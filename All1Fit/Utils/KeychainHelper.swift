import Foundation
import Security

// MARK: - Keychain Helper
/// Simple helper for securely storing credentials in iOS Keychain
enum KeychainHelper {
    
    /// Save password to Keychain
    static func savePassword(_ password: String, for email: String) -> Bool {
        guard let passwordData = password.data(using: .utf8) else { return false }
        
        // Delete existing entry first
        deletePassword(for: email)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: email,
            kSecAttrService as String: "com.all1fit.credentials",
            kSecValueData as String: passwordData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    /// Get password from Keychain
    static func getPassword(for email: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: email,
            kSecAttrService as String: "com.all1fit.credentials",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let passwordData = result as? Data,
              let password = String(data: passwordData, encoding: .utf8) else {
            return nil
        }
        
        return password
    }
    
    /// Delete password from Keychain
    @discardableResult
    static func deletePassword(for email: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: email,
            kSecAttrService as String: "com.all1fit.credentials"
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    /// Check if credentials exist
    static func hasStoredCredentials(for email: String) -> Bool {
        return getPassword(for: email) != nil
    }
}
