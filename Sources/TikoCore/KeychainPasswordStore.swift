import Foundation
import Security

/// One password in the login keychain. macOS lets the app that saved it read
/// it back without asking; any other program has to ask the user first.
public struct KeychainPasswordStore: Sendable {
    public let service: String
    public let account: String

    public init(service: String, account: String) {
        self.service = service
        self.account = account
    }

    /// Where Tiko keeps the Gemini API key.
    public static let geminiAPIKey = KeychainPasswordStore(service: "com.adarshbhardwaj.tiko", account: "gemini-api-key")

    private var itemQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    /// nil when nothing is saved, or the keychain won't hand it over.
    public func load() -> String? {
        var query = itemQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var foundItem: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &foundItem) == errSecSuccess,
              let passwordData = foundItem as? Data else {
            return nil
        }
        return String(data: passwordData, encoding: .utf8)
    }

    public func save(_ password: String) throws {
        let passwordData = Data(password.utf8)
        let updateStatus = SecItemUpdate(itemQuery as CFDictionary, [kSecValueData as String: passwordData] as CFDictionary)
        switch updateStatus {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            var addQuery = itemQuery
            addQuery[kSecValueData as String] = passwordData
            addQuery[kSecAttrLabel as String] = "Tiko: Gemini API key"
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw KeychainError(status: addStatus) }
        default:
            throw KeychainError(status: updateStatus)
        }
    }

    /// Removing something that isn't there counts as done.
    public func delete() throws {
        let deleteStatus = SecItemDelete(itemQuery as CFDictionary)
        guard deleteStatus == errSecSuccess || deleteStatus == errSecItemNotFound else {
            throw KeychainError(status: deleteStatus)
        }
    }
}

public struct KeychainError: LocalizedError, Equatable {
    public let status: OSStatus

    public var errorDescription: String? {
        let systemMessage = SecCopyErrorMessageString(status, nil) as String?
        return "keychain: \(systemMessage ?? "error \(status)")"
    }
}
