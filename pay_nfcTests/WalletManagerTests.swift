import XCTest
@testable import pay_nfc
import SuiKit

final class WalletManagerTests: XCTestCase {
    var keychainManager: MockKeychainManager!
    var walletManager: WalletManager!
    
    override func setUp() {
        super.setUp()
        keychainManager = MockKeychainManager()
        walletManager = WalletManager(network: .testnet, keychainManager: keychainManager)
    }
    
    override func tearDown() {
        keychainManager = nil
        walletManager = nil
        super.tearDown()
    }
    
    func testCreateWallet() {
        // Given
        keychainManager.saveResult = true
        
        // When
        walletManager.createOrUnlockWallet { success in
            // Then
            XCTAssertTrue(success, "Wallet creation should succeed")
            XCTAssertTrue(self.walletManager.hasWallet, "hasWallet should be true after successful creation")
            XCTAssertNotNil(self.walletManager.walletAddress, "Wallet address should not be nil after creation")
            XCTAssertFalse(self.walletManager.walletAddress!.isEmpty, "Wallet address should not be empty")
        }
    }
    
    func testUnlockExistingWallet() {
        // Given
        let testMnemonic = "test unique truly giant eagle silent trend broken unveil gaze young weasel"
        keychainManager.retrieveResult = testMnemonic
        keychainManager.existsResult = true
        
        // When
        walletManager.createOrUnlockWallet { success in
            // Then
            XCTAssertTrue(success, "Wallet unlock should succeed")
            XCTAssertTrue(self.walletManager.hasWallet, "hasWallet should be true after successful unlock")
            XCTAssertNotNil(self.walletManager.walletAddress, "Wallet address should not be nil after unlock")
        }
    }
    
    func testDeleteWallet() {
        // Given
        keychainManager.deleteResult = true
        
        // First create a wallet
        keychainManager.saveResult = true
        walletManager.createOrUnlockWallet { _ in }
        
        // When
        walletManager.deleteWallet()
        
        // Then
        XCTAssertFalse(walletManager.hasWallet, "hasWallet should be false after deletion")
        XCTAssertNil(walletManager.walletAddress, "Wallet address should be nil after deletion")
    }
    
    func testWalletRecovery() {
        // Given
        let testMnemonic = "test unique truly giant eagle silent trend broken unveil gaze young weasel"
        keychainManager.saveResult = true
        
        // When
        walletManager.recoverWalletFromMnemonic(testMnemonic) { success in
            // Then
            XCTAssertTrue(success, "Wallet recovery should succeed")
            XCTAssertTrue(self.walletManager.hasWallet, "hasWallet should be true after recovery")
        }
    }
}

// Mock implementation of KeychainManager for testing
class MockKeychainManager: KeychainManagerProtocol {
    var saveResult: Bool = false
    var retrieveResult: String? = nil
    var existsResult: Bool = false
    var deleteResult: Bool = false
    
    func saveToKeychain(key: String, value: String) -> Bool {
        return saveResult
    }
    
    func retrieveFromKeychain(key: String) -> String? {
        return retrieveResult
    }
    
    func existsInKeychain(key: String) -> Bool {
        return existsResult
    }
    
    func deleteFromKeychain(key: String) -> Bool {
        return deleteResult
    }
    
    func authenticateUser(reason: String, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }
}
