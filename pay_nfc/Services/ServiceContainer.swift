import Foundation

/// 服務容器類，負責創建和管理應用程式中的所有服務
class ServiceContainer {
    static let shared = ServiceContainer()
    
    // 所有服務
    let zkLoginWalletManager: ZkLoginWalletManager
    let blockchainService: SUIBlockchainService
    
    private init() {
        // 初始化 zkLoginWalletManager
        self.zkLoginWalletManager = ZkLoginWalletManager()
        
        // 將 zkLoginWalletManager 傳遞給區塊鏈服務
        self.blockchainService = SUIBlockchainService(zkLoginWalletManager: zkLoginWalletManager)

        print("ServiceContainer: 所有服務已初始化")
    }

    /// 創建一個新的交易視圖模型，並自動注入所需的服務
    func createTransactionViewModel() -> TransactionViewModel {
        let nfcService = NFCService()
        return TransactionViewModel(
            nfcService: nfcService,
            walletManager: zkLoginWalletManager,
            blockchainService: blockchainService
        )
    }
}