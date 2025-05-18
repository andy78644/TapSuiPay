// filepath: Services/KeychainHelper.swift
import Foundation
import Security

/// 簡易 Keychain 助手，用於存儲 String
enum KeychainError: Error {
    case noData
    case unexpectedData
    case unhandledError(OSStatus)
}

class KeychainHelper {
    static func set(_ value: String, service: String) throws {
        guard let data = value.data(using: .utf8) else { return }
        // Delete existing item
        let query = [kSecClass: kSecClassGenericPassword,
                     kSecAttrService: service] as CFDictionary
        SecItemDelete(query)
        // Add new item
        let addQuery = [kSecClass: kSecClassGenericPassword,
                        kSecAttrService: service,
                        kSecValueData: data] as CFDictionary
        let status = SecItemAdd(addQuery, nil)
        guard status == errSecSuccess else { throw KeychainError.unhandledError(status) }
    }

    static func get(_ service: String) throws -> String {
        let query = [kSecClass: kSecClassGenericPassword,
                     kSecAttrService: service,
                     kSecReturnData: true,
                     kSecMatchLimit: kSecMatchLimitOne] as CFDictionary
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query, &item)
        guard status != errSecItemNotFound else { throw KeychainError.noData }
        guard status == errSecSuccess else { throw KeychainError.unhandledError(status) }
        guard let data = item as? Data,
              let str = String(data: data, encoding: .utf8) else {
            throw KeychainError.unexpectedData
        }
        return str
    }

    static func remove(_ service: String) throws {
        let query = [kSecClass: kSecClassGenericPassword,
                     kSecAttrService: service] as CFDictionary
        let status = SecItemDelete(query)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledError(status)
        }
    }
}
