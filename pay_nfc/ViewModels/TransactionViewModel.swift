import Foundation
import Combine

class TransactionViewModel: ObservableObject {
    @Published var currentTransaction: Transaction?
    @Published var transactionState: TransactionState = .idle
    @Published var errorMessage: String?
    @Published var isWalletConnected: Bool = false
    @Published var transactionUrl: URL?
    
    let nfcService: NFCService
    private let zkLoginService: SUIZkLoginService
    private let blockchainService: SUIBlockchainService
    private var cancellables = Set<AnyCancellable>()
    
    // 新增：增加 NFC 狀態的重試機制
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
         zkLoginService: SUIZkLoginService = SUIZkLoginService()) {
        self.nfcService = nfcService
        self.zkLoginService = zkLoginService
        // 重要修改：將 zkLoginService 傳遞給 blockchainService
        self.blockchainService = SUIBlockchainService(zkLoginService: zkLoginService)
        
        setupBindings()
        checkWalletConnection()
        
        // 添加对认证完成通知的监听
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(authenticationCompleted),
            name: Notification.Name("AuthenticationCompleted"),
            object: nil
        )
        
        // 添加对登入狀態變更通知的监听
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(loginStatusChanged),
            name: Notification.Name("LoginStatusChanged"),
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
    
    @objc private func loginStatusChanged() {
        DispatchQueue.main.async {
            print("收到登入狀態變更通知，檢查連接狀態...")
            self.checkWalletConnection()
        }
    }
    
    private func setupBindings() {
        // Bind NFC service scanning state
        nfcService.$isScanning
            .sink { [weak self] isScanning in
                // 當 isScanning 變為 false 且當前狀態是 scanning 時，重置狀態為 idle
                if isScanning {
                    self?.transactionState = .scanning
                } else if self?.transactionState == .scanning {
                    // 重要修改：當掃描停止且當前處於掃描狀態時，重置為空閒狀態
                    DispatchQueue.main.async {
                        self?.transactionState = .idle
                    }
                }
            }
            .store(in: &cancellables)
        
        // Bind zkLogin service wallet address and login status
        // 重要改進: 同時考慮錢包地址和登入狀態
        zkLoginService.$walletAddress
            .combineLatest(blockchainService.$walletAddress)
            .sink { [weak self] (zkAddress, blockchainAddress) in
                // 選擇非空的地址，優先使用 blockchainService 的地址
                let effectiveAddress = !blockchainAddress.isEmpty ? blockchainAddress : zkAddress
                let isConnected = !effectiveAddress.isEmpty
                
                // 只有當狀態確實變化時才更新
                if self?.isWalletConnected != isConnected {
                    print("錢包連接狀態更新: \(isConnected ? "已連接" : "未連接"), 地址: \(effectiveAddress)")
                    self?.isWalletConnected = isConnected
                }
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
            
        // 監聽 blockchainService 的交易狀態
        blockchainService.$transactionStatus
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
            
        // 監聽 blockchainService 的交易 ID 以獲取交易 URL
        blockchainService.$transactionId
            .compactMap { $0 }
            .sink { [weak self] transactionId in
                if let url = self?.blockchainService.getTransactionExplorerURL(transactionId: transactionId) {
                    self?.transactionUrl = url
                    print("交易區塊鏈瀏覽器 URL: \(url)")
                }
            }
            .store(in: &cancellables)
        
        // 監聽 blockchainService 的錯誤訊息
        blockchainService.$errorMessage
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
        
        // 改善對 NFC 錯誤訊息的處理
        nfcService.$nfcMessage
            .compactMap { $0 }
            .sink { [weak self] message in
                guard let self = self else { return }
                
                // 如果是成功訊息就忽略
                if message.contains("success") {
                    self.nfcRetryCount = 0  // 重置重試計數
                    return
                }
                
                // 處理系統資源不可用錯誤
                if message.contains("系統資源暫時不可用") || message.contains("System resource unavailable") {
                    if self.nfcRetryCount < self.maxRetryCount {
                        self.nfcRetryCount += 1
                        // 延遲一秒後自動重試
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            print("⚠️ NFC 資源暫時不可用，正在進行第 \(self.nfcRetryCount) 次重試...")
                            self.errorMessage = "NFC 讀取錯誤，正在重試..."
                            // 重新啟動 NFC 掃描
                            self.startNFCScan()
                        }
                    } else {
                        // 已達最大重試次數
                        self.errorMessage = "NFC 讀取失敗，請確認 NFC 功能已開啟並重新嘗試"
                        self.transactionState = .idle
                        self.nfcRetryCount = 0  // 重置重試計數
                    }
                } else if !message.isEmpty {
                    // 其他錯誤訊息
                    self.errorMessage = message
                    if self.transactionState == .scanning {
                        self.transactionState = .idle
                    }
                    self.nfcRetryCount = 0  // 重置重試計數
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
        // 檢查錢包是否已連接，需要滿足兩個條件：
        // 1. 有效的錢包地址
        // 2. BlockchainService 認為用戶已經登入 (isUserLoggedIn)
        let address = getWalletAddress()
        let blockchainLoggedIn = blockchainService.isUserLoggedIn
        
        // 只有當地址非空且 blockchainService 報告用戶已登入時，才認為錢包已連接
        let connected = !address.isEmpty && blockchainLoggedIn
        
        if isWalletConnected != connected {
            print("checkWalletConnection: 更新錢包連接狀態 - \(connected ? "已連接" : "未連接")")
            print("- 地址: \(address)")
            print("- BlockchainService.isUserLoggedIn: \(blockchainLoggedIn)")
            
            // 更新連接狀態
            isWalletConnected = connected
            
            // 發送通知，告知其他組件連接狀態已變更
            NotificationCenter.default.post(
                name: Notification.Name("WalletConnectionChanged"),
                object: nil,
                userInfo: ["isConnected": connected]
            )
        }
    }
    
    func getWalletAddress() -> String {
        // 優先使用 blockchainService 的地址，因為它更可能是最新的
        let blockchainAddress = blockchainService.walletAddress
        if !blockchainAddress.isEmpty {
            return blockchainAddress
        }
        return zkLoginService.walletAddress
    }
    
    func connectWallet() {
        errorMessage = nil
        zkLoginService.startZkLoginAuthentication()
        transactionState = .authenticating
    }
    
    func signOut() {
        // 登出並清除狀態
        zkLoginService.signOut()
        blockchainService.signOut() // 同時確保 blockchainService 也進行登出操作
        
        // 確保 isWalletConnected 會被更新，但我們實際上不需要手動設置它
        // 因為它會通過我們的 binding 自動更新
        // 不過為了確保立即生效，我們還是直接設置
        isWalletConnected = false
        
        // 重置交易狀態
        resetTransaction()
        
        // 發送額外的通知，確保所有相關組件都能知道登出事件
        NotificationCenter.default.post(
            name: Notification.Name("LoginStatusChanged"),
            object: nil
        )
        
        print("用戶已登出，所有狀態已重置")
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
        guard let recipientName = data["recipient"] else { // Changed from recipientAddressStr to recipientName for clarity
            errorMessage = "交易資料缺少商家名稱"
            transactionState = .failed
            return
        }
        
        // 新增：檢查商品名稱欄位
        guard let merchantName = data["merchant"] else {
            errorMessage = "交易資料缺少商品名稱"
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
        
        // 移除了對 recipientName (原 recipientAddressStr) 的 SUI 地址驗證，因為它現在是商家名稱
        
        // 確保發送者地址有效
        if zkLoginService.walletAddress.isEmpty {
            errorMessage = "尚未連接錢包或錢包地址無效"
            transactionState = .failed
            return
        }
        
        // 創建交易對象
        // 注意: recipientAddress 現在需要一個實際的SUI地址來進行鏈上交易。
        // NFC只提供了商家名稱 (recipientName)。這裡使用一個佔位符。
        // 實際應用中，可能需要從後端獲取商家SUI地址，或商家有一個固定的收款地址。
        let transaction = Transaction(
            recipientAddress: "0xPLACEHOLDER_MERCHANT_SUI_ADDRESS", // Placeholder for actual transaction recipient
            amount: amount,
            senderAddress: zkLoginService.walletAddress,
            coinType: coinType,
            recipient: recipientName, // Assign parsed merchant name
            merchant: merchantName    // Assign parsed product name
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
            errorMessage = "尚無交易可確認"
            transactionState = .failed
            return
        }
        
        transactionState = .processing
        
        // 構建區塊鏈交易
        if let blockchainTransaction = blockchainService.constructTransaction(
            recipientAddress: transaction.recipientAddress,
            amount: transaction.amount,
            coinType: transaction.coinType
        ) {
            // 使用Face ID認證並簽署交易
            blockchainService.authenticateAndSignTransaction(transaction: blockchainTransaction) { [weak self] success, message in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    if success, let txId = message {
                        // 交易成功
                        print("✅ 交易成功完成! 交易ID: \(txId)")
                        self.currentTransaction?.transactionId = txId
                        self.currentTransaction?.status = .completed
                        self.transactionState = .completed
                        
                        // 設置交易瀏覽器 URL (如果不是通過綁定已經設置的話)
                        if self.transactionUrl == nil {
                            self.transactionUrl = self.blockchainService.getTransactionExplorerURL(transactionId: txId)
                        }
                        
                        // 驗證交易是否真實存在於區塊鏈上
                        self.blockchainService.verifyTransaction(transactionId: txId) { verified, verifyMessage in
                            DispatchQueue.main.async {
                                if verified {
                                    print("✅ 交易已在區塊鏈上驗證成功!")
                                } else {
                                    print("⚠️ 交易驗證提示: \(verifyMessage ?? "未知狀態")")
                                    // 即使驗證失敗也不改變成功狀態，因為可能只是網絡延遲
                                }
                            }
                        }
                    } else {
                        // 交易失敗
                        print("❌ 交易失敗: \(message ?? "未知錯誤")")
                        self.errorMessage = message ?? "交易失敗，請稍後再試"
                        self.currentTransaction?.status = .failed
                        self.transactionState = .failed
                    }
                }
            }
        } else {
            errorMessage = blockchainService.errorMessage ?? "無法建立交易，請稍後再試"
            transactionState = .failed
        }
    }
    
    func resetTransaction() {
        currentTransaction = nil
        transactionState = .idle
        errorMessage = nil
    }
}
