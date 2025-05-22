import Foundation
import LocalAuthentication
import SuiKit
import Bip39

/// Provides secure storage for wallet information using the iOS Keychain with biometric protection
class KeychainManager {
    // MARK: - Constants
    
    private enum KeychainKeys {
        static let walletMnemonic = "wallet_mnemonic"
        static let walletPrivateKey = "wallet_private_key"
        static let walletAddress = "wallet_address"
        static let walletScheme = "wallet_scheme"
    }
    
    // MARK: - Singleton
    
    static let shared = KeychainManager()
    
    private init() {}
    
    // MARK: - Biometric Authentication
    
    /// Creates a Secure Enclave access control instance with biometric authentication
    private func createBiometricAccessControl() throws -> SecAccessControl {
        var error: Unmanaged<CFError>?
        
        guard let accessControl = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .biometryCurrentSet,
            &error
        ) else {
            throw KeychainError.accessControlCreationFailed(
                error?.takeRetainedValue() as Error? ?? KeychainError.unknown
            )
        }
        
        return accessControl
    }
    
    /// Checks if biometric authentication is available
    func canUseBiometricAuthentication() -> Bool {
        let context = LAContext()
        var error: NSError?
        
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    
    // MARK: - Wallet Storage
    
    /// Stores a wallet securely in the keychain with biometric protection
    func storeWallet(_ wallet: Wallet) throws {
        // Get mnemonic string
        let mnemonicString = wallet.mnemonic.mnemonic().joined(separator: " ")
        
        // Get account information (assuming first account is the main one)
        let account = wallet.accounts[0]
        let address = try account.address()
        let exportedAccount = try account.export()
        
        // Store wallet components separately with biometric protection
        try storeItem(mnemonicString, forKey: KeychainKeys.walletMnemonic)
        try storeItem(exportedAccount.privateKey, forKey: KeychainKeys.walletPrivateKey)
        try storeItem(address, forKey: KeychainKeys.walletAddress)
        try storeItem(exportedAccount.schema.rawValue, forKey: KeychainKeys.walletScheme)
    }
    
    /// Retrieves a wallet from the keychain, requiring biometric authentication
    func retrieveWallet() throws -> Wallet? {
        // Check if wallet exists
        guard walletExists() else {
            return nil
        }
        
        // Get mnemonic
        guard let mnemonicString = try retrieveItem(forKey: KeychainKeys.walletMnemonic) else {
            throw KeychainError.itemNotFound
        }
        
        // Create mnemonic object
        let mnemonic = try Mnemonic(mnemonic: mnemonicString.components(separatedBy: " "))
        
        // Create wallet with mnemonic
        return try Wallet(mnemonic: mnemonic)
    }
    
    /// Retrieves the stored wallet address without requiring the full wallet to be loaded
    func retrieveWalletAddress() throws -> String? {
        return try retrieveItem(forKey: KeychainKeys.walletAddress)
    }
    
    /// Checks if a wallet exists in the keychain
    func walletExists() -> Bool {
        do {
            return try retrieveItem(forKey: KeychainKeys.walletAddress) != nil
        } catch {
            return false
        }
    }
    
    /// Deletes all wallet data from the keychain
    func deleteWallet() throws {
        try deleteItem(forKey: KeychainKeys.walletMnemonic)
        try deleteItem(forKey: KeychainKeys.walletPrivateKey)
        try deleteItem(forKey: KeychainKeys.walletAddress)
        try deleteItem(forKey: KeychainKeys.walletScheme)
    }
    
    // MARK: - Generic Keychain Methods
    
    /// Stores a string securely in the keychain with biometric protection
    private func storeItem(_ item: String, forKey key: String) throws {
        guard let data = item.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }
        
        let accessControl = try createBiometricAccessControl()
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessControl as String: accessControl,
            kSecUseAuthenticationUI as String: kSecUseAuthenticationUIAllow
        ]
        
        // Delete any existing item first
        SecItemDelete(query as CFDictionary)
        
        // Add the new item
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.storeError(status)
        }
    }
    
    /// Retrieves a string from the keychain, requiring biometric authentication
    private func retrieveItem(forKey key: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true,
            kSecUseOperationPrompt as String: "Access your wallet",
            kSecUseAuthenticationUI as String: kSecUseAuthenticationUIAllow
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status != errSecItemNotFound else {
            return nil
        }
        
        guard status == errSecSuccess else {
            throw KeychainError.retrieveError(status)
        }
        
        guard let data = item as? Data, let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.decodingFailed
        }
        
        return string
    }
    
    /// Deletes an item from the keychain
    private func deleteItem(forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteError(status)
        }
    }
}

// MARK: - Custom Errors

enum KeychainError: Error {
    case accessControlCreationFailed(Error)
    case encodingFailed
    case decodingFailed
    case storeError(OSStatus)
    case retrieveError(OSStatus)
    case deleteError(OSStatus)
    case itemNotFound
    case unknown
}
