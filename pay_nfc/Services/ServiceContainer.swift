import Foundation
import SuiKit

/// Service container class responsible for creating and managing all services in the application
class ServiceContainer {
    static let shared = ServiceContainer()
    
    // Configuration
    private let network: SuiProvider.Network = .testnet
    private let packageId: String = "0x..." // TODO: Replace with actual deployed package ID
    private let registryObjectId: String = "0x..." // TODO: Replace with actual registry object ID
    
    // Services
    let keychainManager: KeychainManager
    let walletManager: WalletManager
    let transactionService: TransactionService
    let tapSuiPayService: TapSuiPayService
    let googleAuthService: GoogleAuthService
    
    private init() {
        // Initialize services
        self.keychainManager = KeychainManager.shared
        self.walletManager = WalletManager(network: network, keychainManager: keychainManager)
        self.transactionService = TransactionService(network: network, walletManager: walletManager)
        self.tapSuiPayService = TapSuiPayService(
            transactionService: transactionService,
            packageId: packageId,
            registryObjectId: registryObjectId
        )
        self.googleAuthService = GoogleAuthService()
        
        print("ServiceContainer: All services initialized")
    }
    
    /// Creates a new transaction view model with injected services
    func createTransactionViewModel() -> TransactionViewModel {
        let nfcService = NFCService()
        return TransactionViewModel(
            nfcService: nfcService,
            walletManager: walletManager,
            transactionService: transactionService,
            tapSuiPayService: tapSuiPayService
        )
    }
}