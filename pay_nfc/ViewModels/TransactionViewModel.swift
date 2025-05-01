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
        // 檢查必要欄位
        guard let recipientAddressStr = data["recipient"] else {
            errorMessage = "交易資料缺少收款人地址"
            transactionState = .failed
            return
        }
        
        // 確保 amount 欄位存在且可轉換為有效數字
        guard let amountStr = data["amount"] else {
            errorMessage = "交易資料缺少金額欄位"
            transactionState = .failed
            return
        }
        
        // 確保 coinType 欄位存在
        guard let coinType = data["coinType"] else {
            errorMessage = "交易資料缺少幣種欄位"
            transactionState = .failed
            return
        }
        
        // 嘗試解析金額
        guard let amount = Double(amountStr), amount > 0 else {
            errorMessage = "交易金額格式無效或小於等於零: \(amountStr)"
            transactionState = .failed
            return
        }
        
        // 檢查收款人地址格式
        if recipientAddressStr.isEmpty || !isValidSuiAddress(recipientAddressStr) {
            errorMessage = "收款人地址格式無效: \(recipientAddressStr)"
            transactionState = .failed
            return
        }
        
        // 確保發送者地址有效
        if zkLoginService.walletAddress.isEmpty {
            errorMessage = "尚未連接錢包或錢包地址無效"
            transactionState = .failed
            return
        }
        
        // 創建交易對象
        let transaction = Transaction(
            recipientAddress: recipientAddressStr,
            amount: amount,
            senderAddress: zkLoginService.walletAddress,
            coinType: coinType
        )
        
        currentTransaction = transaction
        transactionState = .confirmingTransaction
    }
    
    // 簡單驗證 SUI 地址格式
    private func isValidSuiAddress(_ address: String) -> Bool {
        // SUI 地址通常以 "0x" 開頭，後跟 64 個十六進制字符 (32 bytes)
        // 這是一個簡化的檢查，完整檢查還應該驗證十六進制字符有效性
        return address.hasPrefix("0x") && address.count == 66
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
