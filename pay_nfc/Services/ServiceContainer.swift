import Foundation

/// 服務容器類，負責創建和管理應用程式中的所有服務
class ServiceContainer: ObservableObject {
    static let shared = ServiceContainer()
    
    // 所有服務
    let zkLoginService: SUIZkLoginService
    let blockchainService: SUIBlockchainService
    let nfcService: NFCService
    let merchantRegistryService: MerchantRegistryService // 新增服務

    // Change 'private init()' to 'init()' to make it accessible
    init() {
        // 初始化 zkLogin 服務
        self.zkLoginService = SUIZkLoginService()
        
        // 將 zkLogin 服務傳遞給區塊鏈服務
        self.blockchainService = SUIBlockchainService(zkLoginService: zkLoginService)
        
        self.nfcService = NFCService(blockchainService: self.blockchainService, zkLoginService: self.zkLoginService)
        self.merchantRegistryService = MerchantRegistryService() // 初始化新服務

        print("ServiceContainer: 所有服務已初始化")
    }
    
    /// 創建一個新的交易視圖模型，並自動注入所需的服務
    func createTransactionViewModel() -> TransactionViewModel {
        return TransactionViewModel(
            nfcService: nfcService,
            zkLoginService: zkLoginService
        )
    }
}