import Foundation
import Security

enum KeychainError: Error {
    case duplicateEntry
    case unknown(OSStatus)
    case itemNotFound
    case invalidData
}

class KeychainManager {
    static let shared = KeychainManager()
    private let service = "com.mou.ClashDash"
    
    private init() {}
    
    func saveCredentials(_ username: String, _ password: String, for serverId: UUID) throws {
        let credentials = "\(username):\(password)".data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: serverId.uuidString,
            kSecValueData as String: credentials
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecDuplicateItem {
            // 如果已存在，则更新
            let updateQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: serverId.uuidString
            ]
            
            let attributes: [String: Any] = [
                kSecValueData as String: credentials
            ]
            
            let updateStatus = SecItemUpdate(updateQuery as CFDictionary, attributes as CFDictionary)
            
            guard updateStatus == errSecSuccess else {
                throw KeychainError.unknown(updateStatus)
            }
        } else if status != errSecSuccess {
            throw KeychainError.unknown(status)
        }
    }
    
    func getCredentials(for serverId: UUID) throws -> (username: String, password: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: serverId.uuidString,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let credentials = String(data: data, encoding: .utf8),
              let separatorIndex = credentials.firstIndex(of: ":")
        else {
            throw KeychainError.itemNotFound
        }
        
        let username = String(credentials[..<separatorIndex])
        let password = String(credentials[credentials.index(after: separatorIndex)...])
        
        return (username, password)
    }
    
    func deleteCredentials(for serverId: UUID) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: serverId.uuidString
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unknown(status)
        }
    }
} 