import Foundation
import SuiKit
import Bip39
import Combine
import LocalAuthentication

/// Manages wallet creation, storage, and retrieval with biometric protection
class WalletManager: ObservableObject {
    // MARK: - Properties
    
    /// The current wallet address
    @Published var walletAddress: String = ""
    
    /// Indicates if a wallet is available
    @Published var hasWallet: Bool = false
    
    /// The network to use for SUI transactions
    private let network: SuiProvider.Network
    
    /// The keychain manager for secure storage
    private let keychainManager: KeychainManager
    
    /// The currently loaded wallet
    private var wallet: Wallet?
    
    // MARK: - Initialization
    
    /// Initialize with a specific network and keychain manager
    init(network: SuiProvider.Network = .testnet, keychainManager: KeychainManager = KeychainManager.shared) {
        self.network = network
        self.keychainManager = keychainManager
        
        // Check if wallet exists on initialization
        self.hasWallet = keychainManager.walletExists()
        
        // Try to load the wallet address (doesn't require biometric authentication)
        if hasWallet {
            do {
                if let address = try keychainManager.retrieveWalletAddress() {
                    self.walletAddress = address
                }
            } catch {
                print("Failed to load wallet address: \(error)")
            }
        }
    }
    
    // MARK: - Wallet Management
    
    /// Creates a new wallet with ED25519 keys and stores it securely
    /// - Returns: The newly created wallet
    /// - Throws: Errors from wallet creation or storage
    func createWallet() throws -> Wallet {
        let wallet = try Wallet() // Creates a new wallet with default ED25519 keys
        
        // Store the wallet securely
        try keychainManager.storeWallet(wallet)
        
        // Update state
        self.wallet = wallet
        self.hasWallet = true
        self.walletAddress = try wallet.accounts[0].address()
        
        return wallet
    }
    
    /// Imports a wallet from a mnemonic phrase and stores it securely
    /// - Parameter mnemonic: The mnemonic phrase as a space-separated string
    /// - Returns: The imported wallet
    /// - Throws: Errors from wallet import or storage
    func importWallet(mnemonic: String) throws -> Wallet {
        // Create wallet from mnemonic
        let mnemonicObj = try Mnemonic(mnemonic: mnemonic.components(separatedBy: " "))
        let wallet = try Wallet(mnemonic: mnemonicObj)
        
        // Store the wallet securely
        try keychainManager.storeWallet(wallet)
        
        // Update state
        self.wallet = wallet
        self.hasWallet = true
        self.walletAddress = try wallet.accounts[0].address()
        
        return wallet
    }
    
    /// Gets the current wallet, loading it from secure storage if necessary
    /// - Returns: The current wallet
    /// - Throws: Errors from wallet retrieval
    func getCurrentWallet() throws -> Wallet {
        // If wallet is already loaded, return it
        if let wallet = self.wallet {
            return wallet
        }
        
        // Otherwise, try to retrieve it from secure storage (requires biometric authentication)
        guard let retrievedWallet = try keychainManager.retrieveWallet() else {
            throw WalletError.walletNotFound
        }
        
        // Cache the wallet and update state
        self.wallet = retrievedWallet
        self.hasWallet = true
        self.walletAddress = try retrievedWallet.accounts[0].address()
        
        return retrievedWallet
    }
    
    /// Gets the current wallet address
    /// - Returns: The wallet address as a string
    /// - Throws: Errors from address retrieval
    func getWalletAddress() throws -> String {
        // If we already have the address, return it
        if !walletAddress.isEmpty {
            return walletAddress
        }
        
        // Otherwise, try to get it from the wallet or keychain
        if let wallet = self.wallet {
            let address = try wallet.accounts[0].address()
            self.walletAddress = address
            return address
        }
        
        if let address = try keychainManager.retrieveWalletAddress() {
            self.walletAddress = address
            return address
        }
        
        throw WalletError.addressNotFound
    }
    
    /// Deletes the wallet from secure storage
    /// - Throws: Errors from wallet deletion
    func deleteWallet() throws {
        try keychainManager.deleteWallet()
        self.wallet = nil
        self.hasWallet = false
        self.walletAddress = ""
    }
    
    /// Gets the mnemonic phrase for backup
    /// - Returns: The mnemonic phrase as a space-separated string
    /// - Throws: Errors from wallet retrieval
    func getMnemonicPhrase() throws -> String {
        let wallet = try getCurrentWallet()
        return wallet.mnemonic.mnemonic().joined(separator: " ")
    }
    
    /// Checks if biometric authentication is available on this device
    /// - Returns: True if biometric authentication is available
    func canUseBiometricAuthentication() -> Bool {
        return keychainManager.canUseBiometricAuthentication()
    }
}

// MARK: - Custom Errors

enum WalletError: Error {
    case walletNotFound
    case addressNotFound
    case invalidMnemonic
    case walletCreationFailed(Error)
}
