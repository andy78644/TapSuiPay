import Foundation
import Combine

class TransactionViewModel: ObservableObject {
    @Published var currentTransaction: Transaction?
    @Published var transactionState: TransactionState = .idle
    @Published var errorMessage: String?
    @Published var isWalletConnected: Bool = false
    @Published var transactionUrl: URL?
    
    let nfcService: NFCService
    private let walletManager: WalletManager
    private let transactionService: TransactionService
    private let tapSuiPayService: TapSuiPayService
    private var cancellables = Set<AnyCancellable>()
    
    // NFC retry mechanism
    private var nfcRetryCount = 0
    private let maxRetryCount = 2
    
    enum TransactionState {
        case idle
        case authenticating
        case scanning
        case confirmingTransaction
        case processing
        case completed
        case failed
    }
    
    init(nfcService: NFCService = NFCService(),
         walletManager: WalletManager = ServiceContainer.shared.walletManager,
         transactionService: TransactionService = ServiceContainer.shared.transactionService,
         tapSuiPayService: TapSuiPayService = ServiceContainer.shared.tapSuiPayService) {
        self.nfcService = nfcService
        self.walletManager = walletManager
        self.transactionService = transactionService
        self.tapSuiPayService = tapSuiPayService
        
        setupBindings()
        checkWalletConnection()
    }
    
    private func setupBindings() {
        // Bind NFC service scanning state
        nfcService.$isScanning
            .sink { [weak self] isScanning in
                if isScanning {
                    self?.transactionState = .scanning
                } else if self?.transactionState == .scanning {
                    DispatchQueue.main.async {
                        self?.transactionState = .idle
                    }
                }
            }
            .store(in: &cancellables)
        
        // Bind wallet manager's wallet state
        walletManager.$hasWallet
            .sink { [weak self] hasWallet in
                self?.isWalletConnected = hasWallet
            }
            .store(in: &cancellables)
        
        // Bind wallet manager's authentication state
        walletManager.$isAuthenticating
            .sink { [weak self] isAuthenticating in
                if isAuthenticating {
                    self?.transactionState = .authenticating
                }
            }
            .store(in: &cancellables)
            
        // Bind transaction service's transaction status
        transactionService.$transactionStatus
            .sink { [weak self] status in
                switch status {
                case .inProgress:
                    self?.transactionState = .processing
                case .completed:
                    self?.transactionState = .completed
                case .failed:
                    self?.transactionState = .failed
                default:
                    break
                }
            }
            .store(in: &cancellables)
            
        // Bind transaction service's transaction ID for explorer URL
        transactionService.$transactionId
            .compactMap { $0 }
            .sink { [weak self] transactionId in
                if let url = self?.transactionService.getTransactionExplorerURL(transactionId: transactionId) {
                    self?.transactionUrl = url
                    print("Transaction explorer URL: \(url)")
                }
            }
            .store(in: &cancellables)
        
        // Bind transaction service's error message
        transactionService.$errorMessage
            .compactMap { $0 }
            .sink { [weak self] message in
                self?.errorMessage = message
                self?.transactionState = .failed
            }
            .store(in: &cancellables)
        
        nfcService.$transactionData
            .compactMap { $0 }
            .sink { [weak self] data in
                self?.processTransactionData(data)
            }
            .store(in: &cancellables)
        
        // NFC error message handling
        nfcService.$nfcMessage
            .compactMap { $0 }
            .sink { [weak self] message in
                guard let self = self else { return }
                
                // Ignore success messages
                if message.contains("success") {
                    self.nfcRetryCount = 0  // Reset retry counter
                    return
                }
                
                // Handle system resource unavailable error
                if message.contains("系統資源暫時不可用") || message.contains("System resource unavailable") {
                    if self.nfcRetryCount < self.maxRetryCount {
                        self.nfcRetryCount += 1
                        // Auto-retry after a delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            print("⚠️ NFC resource temporarily unavailable, retrying \(self.nfcRetryCount)...")
                            self.errorMessage = "NFC reading error, retrying..."
                            // Restart NFC scanning
                            self.startNFCScan()
                        }
                    } else {
                        // Max retries reached
                        self.errorMessage = "NFC reading failed, please check NFC is enabled and try again"
                        self.transactionState = .idle
                        self.nfcRetryCount = 0  // Reset retry counter
                    }
                } else if !message.isEmpty {
                    // Other error messages
                    self.errorMessage = message
                    if self.transactionState == .scanning {
                        self.transactionState = .idle
                    }
                    self.nfcRetryCount = 0  // Reset retry counter
                }
            }
            .store(in: &cancellables)
        
        // Bind wallet manager's error message
        walletManager.$errorMessage
            .compactMap { $0 }
            .sink { [weak self] message in
                self?.errorMessage = message
                self?.transactionState = .failed
            }
            .store(in: &cancellables)
    }
    
    private func checkWalletConnection() {
        // Check if wallet is connected
        isWalletConnected = walletManager.hasWallet
    }
    
    func getWalletAddress() -> String {
        return walletManager.walletAddress
    }
    
    func connectWallet() {
        errorMessage = nil
        walletManager.createOrUnlockWallet { [weak self] success in
            if success {
                self?.isWalletConnected = true
                self?.transactionState = .idle
            } else {
                self?.errorMessage = "Failed to access wallet"
                self?.transactionState = .failed
            }
        }
        transactionState = .authenticating
    }
    
    func signOut() {
        walletManager.deleteWallet()
        isWalletConnected = false
        resetTransaction()
    }
    
    func startNFCScan() {
        // Ensure wallet is connected before scanning
        guard isWalletConnected else {
            errorMessage = "Please connect your wallet first"
            return
        }
        
        errorMessage = nil
        nfcService.startScanning()
        transactionState = .scanning
    }
    
    private func processTransactionData(_ data: [String: String]) {
        // Check required fields
        guard let recipientAddressStr = data["recipient"] else {
            errorMessage = "Transaction data missing recipient address"
            transactionState = .failed
            return
        }
        
        // Ensure amount field exists and can be converted to a valid number
        guard let amountStr = data["amount"] else {
            errorMessage = "Transaction data missing amount field"
            transactionState = .failed
            return
        }
        
        // Ensure coinType field exists
        guard let coinType = data["coinType"] else {
            errorMessage = "Transaction data missing coin type field"
            transactionState = .failed
            return
        }
        
        // Try to parse the amount
        guard let amount = Double(amountStr), amount > 0 else {
            errorMessage = "Transaction amount invalid or less than or equal to zero: \(amountStr)"
            transactionState = .failed
            return
        }
        
        // Check recipient address format
        if recipientAddressStr.isEmpty || !isValidSuiAddress(recipientAddressStr) {
            errorMessage = "Recipient address format invalid: \(recipientAddressStr)"
            transactionState = .failed
            return
        }
        
        // Ensure sender address is valid
        guard let senderAddress = walletManager.walletAddress, !senderAddress.isEmpty else {
            errorMessage = "Wallet not connected or address invalid"
            transactionState = .failed
            return
        }
        
        // Create transaction object
        let transaction = Transaction(
            recipientAddress: recipientAddressStr,
            amount: amount,
            senderAddress: senderAddress,
            coinType: coinType
        )
        
        currentTransaction = transaction
        transactionState = .confirmingTransaction
    }
    
    // Simple validation of SUI address format
    private func isValidSuiAddress(_ address: String) -> Bool {
        // SUI address typically starts with "0x" followed by 64 hexadecimal characters (32 bytes)
        // This is a simplified check, a complete check should also validate the hexadecimal characters
        return address.hasPrefix("0x") && address.count == 66
    }
    
    func confirmAndSignTransaction() {
        guard let transaction = currentTransaction else {
            errorMessage = "No transaction to confirm"
            transactionState = .failed
            return
        }
        
        transactionState = .processing
        
        // Authenticate with biometric authentication and sign transaction
        tapSuiPayService.makePayment(
            recipientAddress: transaction.recipientAddress,
            amount: transaction.amount,
            coinType: transaction.coinType
        ) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                switch result {
                case .success(let txId):
                    // Transaction successful
                    print("✅ Transaction completed successfully! Transaction ID: \(txId)")
                    self.currentTransaction?.transactionId = txId
                    self.currentTransaction?.status = .completed
                    self.transactionState = .completed
                    
                    // Set transaction explorer URL (if not already set via binding)
                    if self.transactionUrl == nil {
                        self.transactionUrl = self.transactionService.getTransactionExplorerURL(transactionId: txId)
                    }
                    
                    // Verify the transaction on the blockchain
                    self.transactionService.verifyTransaction(transactionId: txId) { verified, verifyMessage in
                        DispatchQueue.main.async {
                            if verified {
                                print("✅ Transaction verified successfully on blockchain!")
                            } else {
                                print("⚠️ Transaction verification notice: \(verifyMessage ?? "unknown status")")
                                // Don't change success status even if verification fails, as it might just be network delay
                            }
                        }
                    }
                    
                case .failure(let error):
                    // Transaction failed
                    print("❌ Transaction failed: \(error.localizedDescription)")
                    self.errorMessage = error.localizedDescription
                    self.currentTransaction?.status = .failed
                    self.transactionState = .failed
                }
            }
        }
    }
    
    func resetTransaction() {
        currentTransaction = nil
        transactionState = .idle
        errorMessage = nil
    }
}
