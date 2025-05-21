import Foundation
import SuiKit
import Combine

/// Service for handling SUI blockchain transactions
class TransactionService {
    // MARK: - Properties
    
    /// The provider for SUI network operations
    private let provider: SuiProvider
    
    /// The wallet manager for retrieving wallet information
    private let walletManager: WalletManager
    
    /// The current status of the transaction
    @Published var transactionStatus: TransactionStatus = .idle
    
    /// The transaction digest of the most recent transaction
    @Published var transactionDigest: String?
    
    // MARK: - Initialization
    
    /// Initialize with a specific network and wallet manager
    init(network: SuiProvider.Network = .testnet, walletManager: WalletManager) {
        self.provider = SuiProvider(network: network)
        self.walletManager = walletManager
    }
    
    // MARK: - Transaction Operations
    
    /// Transfers SUI to an address
    /// - Parameters:
    ///   - amount: Amount in MIST units (1 SUI = 10^9 MIST)
    ///   - to: The recipient address
    /// - Returns: The transaction digest
    func transferSUI(amount: UInt64, to: String) async throws -> String {
        // Update status
        transactionStatus = .preparing
        
        // Create transaction block
        var txb = try TransactionBlock()
        
        // Split the amount from the gas coin
        let coin = try txb.splitCoin(txb.gas, [txb.pure(value: .number(amount))])
        
        // Transfer the split coin to the recipient
        try txb.transferObjects([coin], try AccountAddress.fromHex(to))
        
        // Execute the transaction
        return try await executeTransaction(transactionBlock: txb)
    }
    
    /// Builds and executes a custom transaction
    /// - Parameter transactionBlock: The transaction block to execute
    /// - Returns: The transaction digest
    func executeTransaction(transactionBlock: TransactionBlock) async throws -> String {
        // Update status
        transactionStatus = .submitting
        
        // Get the wallet
        let wallet = try walletManager.getCurrentWallet()
        
        // Get the account from the wallet (first account)
        let account = wallet.accounts[0]
        
        // Create the signer
        let signer = RawSigner(account: account, provider: provider)
        
        // Sign and execute the transaction
        var txb = transactionBlock
        var result = try await signer.signAndExecuteTransaction(transactionBlock: &txb)
        
        // Update status to processing
        transactionStatus = .processing
        transactionDigest = result.digest
        
        // Wait for the transaction to be confirmed
        result = try await provider.waitForTransaction(tx: result.digest)
        
        // Update status to completed
        transactionStatus = .completed
        
        return result.digest
    }
    
    /// Signs a transaction block
    /// - Parameter transactionBlock: The transaction block to sign
    /// - Returns: The signature
    func signTransaction(transactionBlock: TransactionBlock) throws -> Signature {
        // Get the wallet
        let wallet = try walletManager.getCurrentWallet()
        
        // Get the account from the wallet (first account)
        let account = wallet.accounts[0]
        
        // Prepare the transaction
        var txb = transactionBlock
        let bytes = try txb.build(provider)
        
        // Sign the transaction
        return try account.signTransactionBlock([UInt8](bytes))
    }
    
    /// Estimates the gas cost for a transaction
    /// - Parameter transactionBlock: The transaction block to estimate gas for
    /// - Returns: The estimated gas cost in MIST
    func estimateGasCost(transactionBlock: TransactionBlock) async throws -> UInt64 {
        // Get the wallet address
        let address = try walletManager.getWalletAddress()
        
        // Prepare the transaction
        var txb = transactionBlock
        
        // Set the sender if not already set
        if txb.sender == nil {
            try txb.setSender(sender: address)
        }
        
        // Build gas estimation request options
        let options = SuiTransactionBlockResponseOptions(
            showEffects: true,
            showObjectChanges: false,
            showEvents: false,
            showBalanceChanges: true
        )
        
        // Dry run to get estimate
        let dryRunResult = try await provider.dryRunTransaction(
            txb: txb,
            options: options
        )
        
        // Extract gas used from the result
        if let effects = dryRunResult.effects {
            return effects.gasUsed.computationCost + effects.gasUsed.storageCost
        }
        
        throw TransactionError.gasEstimationFailed
    }
    
    /// Gets the SUI balance for the current wallet
    /// - Returns: The balance in SUI (not MIST)
    func getBalance() async throws -> Double {
        // Get the wallet address
        let address = try walletManager.getWalletAddress()
        
        // Get the balance
        let balanceResponse = try await provider.getBalance(account: address)
        
        // Convert from MIST to SUI (1 SUI = 10^9 MIST)
        return Double(balanceResponse.totalBalance) / 1_000_000_000.0
    }
    
    /// Reset the transaction state
    func resetTransactionState() {
        transactionStatus = .idle
        transactionDigest = nil
    }
}

// MARK: - Transaction Status Enum

/// Represents the status of a transaction
enum TransactionStatus {
    case idle
    case preparing
    case submitting
    case processing
    case completed
    case failed(Error)
}

// MARK: - Custom Errors

enum TransactionError: Error {
    case transactionFailed(String)
    case insufficientBalance
    case invalidRecipient
    case gasEstimationFailed
}
