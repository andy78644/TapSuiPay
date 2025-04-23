import Foundation
import Combine

class TransactionViewModel: ObservableObject {
    @Published var currentTransaction: Transaction?
    @Published var transactionState: TransactionState = .idle
    @Published var errorMessage: String?
    @Published var isWalletConnected: Bool = false
    
    let nfcService: NFCService
    private let zkLoginService: SUIZkLoginService
    private var cancellables = Set<AnyCancellable>()
    
    enum TransactionState {
        case idle
        case authenticating
        case scanning
        case confirmingTransaction
        case processing
        case completed
        case failed
    }
    
    init(nfcService: NFCService = NFCService(), zkLoginService: SUIZkLoginService = SUIZkLoginService()) {
        self.nfcService = nfcService
        self.zkLoginService = zkLoginService
        
        setupBindings()
        checkWalletConnection()
        
        // 添加对认证完成通知的监听
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(authenticationCompleted),
            name: Notification.Name("AuthenticationCompleted"),
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func authenticationCompleted() {
        DispatchQueue.main.async {
            print("收到认证完成通知，更新UI状态...")
            self.transactionState = .idle
            self.checkWalletConnection()
        }
    }
    
    private func setupBindings() {
        // Bind NFC service scanning state
        nfcService.$isScanning
            .sink { [weak self] isScanning in
                if isScanning {
                    self?.transactionState = .scanning
                }
            }
            .store(in: &cancellables)
        
        // Bind zkLogin service wallet address
        zkLoginService.$walletAddress
            .sink { [weak self] address in
                self?.isWalletConnected = !address.isEmpty
            }
            .store(in: &cancellables)
        
        // Bind zkLogin service authentication state
        zkLoginService.$isAuthenticating
            .sink { [weak self] isAuthenticating in
                if isAuthenticating {
                    self?.transactionState = .authenticating
                }
            }
            .store(in: &cancellables)
        
        nfcService.$transactionData
            .compactMap { $0 }
            .sink { [weak self] data in
                self?.processTransactionData(data)
            }
            .store(in: &cancellables)
        
        nfcService.$nfcMessage
            .compactMap { $0 }
            .filter { !$0.isEmpty && $0 != "Transaction data read successfully" }
            .sink { [weak self] message in
                self?.errorMessage = message
                if self?.transactionState == .scanning {
                    self?.transactionState = .idle
                }
            }
            .store(in: &cancellables)
        
        zkLoginService.$errorMessage
            .compactMap { $0 }
            .sink { [weak self] message in
                self?.errorMessage = message
                self?.transactionState = .failed
            }
            .store(in: &cancellables)
    }
    
    private func checkWalletConnection() {
        // Check if wallet is connected
        isWalletConnected = !zkLoginService.walletAddress.isEmpty
    }
    
    func getWalletAddress() -> String {
        return zkLoginService.walletAddress
    }
    
    func connectWallet() {
        errorMessage = nil
        zkLoginService.startZkLoginAuthentication()
        transactionState = .authenticating
    }
    
    func signOut() {
        zkLoginService.signOut()
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
        guard let recipientAddressStr = data["recipient"],
              let amountStr = data["amount"],
              let amount = Double(amountStr) else {
            errorMessage = "Invalid transaction data format"
            transactionState = .failed
            return
        }
        
        // 创建交易对象
        let transaction = Transaction(
            recipientAddress: recipientAddressStr,
            amount: amount,
            senderAddress: zkLoginService.walletAddress
        )
        
        currentTransaction = transaction
        transactionState = .confirmingTransaction
    }
    
    func confirmAndSignTransaction() {
        guard let transaction = currentTransaction else {
            errorMessage = "No transaction to confirm"
            transactionState = .failed
            return
        }
        
        transactionState = .processing
        
        // 在真实应用中，这里应该调用zkLoginService中的交易签名方法
        // 目前模拟一个成功的交易
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self = self else { return }
            
            let txId = "0x" + String((0..<64).map { _ in "0123456789abcdef".randomElement()! })
            self.currentTransaction?.transactionId = txId
            self.currentTransaction?.status = .completed
            self.transactionState = .completed
        }
    }
    
    func resetTransaction() {
        currentTransaction = nil
        transactionState = .idle
        errorMessage = nil
    }
}
