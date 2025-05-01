import Foundation

/// 服務容器類，負責創建和管理應用程式中的所有服務
class ServiceContainer {
    static let shared = ServiceContainer()
    
    // 所有服務
    let zkLoginService: SUIZkLoginService
    let blockchainService: SUIBlockchainService
    
    private init() {
        // 初始化 zkLogin 服務
        self.zkLoginService = SUIZkLoginService()
        
        // 將 zkLogin 服務傳遞給區塊鏈服務
        self.blockchainService = SUIBlockchainService(zkLoginService: zkLoginService)
        
        print("ServiceContainer: 所有服務已初始化")
    }
    
    /// 創建一個新的交易視圖模型，並自動注入所需的服務
    func createTransactionViewModel() -> TransactionViewModel {
        let nfcService = NFCService()
        return TransactionViewModel(
            nfcService: nfcService,
            zkLoginService: zkLoginService
        )
    }
}