import XCTest
@testable import pay_nfc
import SuiKit

final class TransactionServiceTests: XCTestCase {
    var mockWalletManager: MockWalletManager!
    var transactionService: TransactionService!
    
    override func setUp() {
        super.setUp()
        mockWalletManager = MockWalletManager()
        transactionService = TransactionService(network: .testnet, walletManager: mockWalletManager)
    }
    
    override func tearDown() {
        mockWalletManager = nil
        transactionService = nil
        super.tearDown()
    }
    
    func testTransactionExplorerURL() {
        // Given
        let transactionId = "ABC123"
        
        // When
        let url = transactionService.getTransactionExplorerURL(transactionId: transactionId)
        
        // Then
        XCTAssertNotNil(url, "Explorer URL should not be nil")
        XCTAssertTrue(url!.absoluteString.contains(transactionId), "URL should contain the transaction ID")
    }
    
    func testSuccessfulTransaction() {
        // Given
        mockWalletManager.mockWallet = MockWallet(shouldSucceed: true)
        mockWalletManager.hasWallet = true
        
        // When
        transactionService.transferSUI(to: "0x123", amount: 1.0) { result in
            // Then
            switch result {
            case .success(let txId):
                XCTAssertFalse(txId.isEmpty, "Transaction ID should not be empty")
                XCTAssertEqual(self.transactionService.transactionStatus, .completed, "Transaction status should be completed")
            case .failure:
                XCTFail("Transaction should succeed")
            }
        }
    }
    
    func testFailedTransaction() {
        // Given
        mockWalletManager.mockWallet = MockWallet(shouldSucceed: false)
        mockWalletManager.hasWallet = true
        
        // When
        transactionService.transferSUI(to: "0x123", amount: 1.0) { result in
            // Then
            switch result {
            case .success:
                XCTFail("Transaction should fail")
            case .failure(let error):
                XCTAssertNotNil(error, "Error should not be nil")
                XCTAssertEqual(self.transactionService.transactionStatus, .failed, "Transaction status should be failed")
            }
        }
    }
    
    func testNoWalletTransaction() {
        // Given
        mockWalletManager.hasWallet = false
        
        // When
        transactionService.transferSUI(to: "0x123", amount: 1.0) { result in
            // Then
            switch result {
            case .success:
                XCTFail("Transaction should fail when no wallet")
            case .failure(let error):
                XCTAssertNotNil(error, "Error should not be nil")
                XCTAssertEqual(self.transactionService.transactionStatus, .failed, "Transaction status should be failed")
                XCTAssertEqual(self.transactionService.errorMessage, "Wallet not available", "Error message should indicate wallet not available")
            }
        }
    }
}

// Mock classes for testing

class MockWalletManager: WalletManager {
    var mockWallet: MockWallet?
    
    override init(network: SuiProvider.Network = .testnet, keychainManager: KeychainManagerProtocol = KeychainManager.shared) {
        super.init(network: network, keychainManager: keychainManager)
    }
    
    override func getWallet() -> Wallet? {
        return mockWallet
    }
}

class MockWallet: Wallet {
    private let shouldSucceed: Bool
    
    init(shouldSucceed: Bool) {
        self.shouldSucceed = shouldSucceed
        super.init()
    }
    
    override func signAndExecuteTransaction(transaction: TransactionBlock, account: Account, options: ExecuteTransactionOptions? = nil, requestType: ExecuteTransactionRequestType = .waitForLocalExecution) async throws -> TransactionResult {
        if shouldSucceed {
            return TransactionResult(digest: "mock_txid_success_\(UUID().uuidString)")
        } else {
            struct MockError: Error {
                let message: String
            }
            throw MockError(message: "Mock transaction failed")
        }
    }
}
