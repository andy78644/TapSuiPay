import Foundation
import CoreNFC
import SuiKit  // 添加SuiKit導入

@available(iOS 13.0, *)
class NFCService: NSObject, ObservableObject, NFCNDEFReaderSessionDelegate {
    func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {
        // Optional: you can add logging or UI updates here if desired
    }
    @Published var isScanning = false
    @Published var nfcMessage: String?
    @Published var transactionData: [String: String]?
    @Published var transactionStatus: String? // 添加交易狀態追蹤
    @Published var transactionId: String? // 添加交易ID追蹤
    
    private var session: NFCNDEFReaderSession?
    private var writePayload: String?
    
    // 新增：追蹤是否有作業正在進行中
    private var isSessionActive = false
    
    // 添加依賴服務
    private var blockchainService: SUIBlockchainService?
    private var zkLoginService: SUIZkLoginService?
    
    // 初始化方法，注入區塊鏈服務
    init(blockchainService: SUIBlockchainService? = nil, zkLoginService: SUIZkLoginService? = nil) {
        self.blockchainService = blockchainService
        self.zkLoginService = zkLoginService
        super.init()
    }
    
    // 新增方法：清除NFC相關狀態
    private func resetNFCState() {
        DispatchQueue.main.async {
            self.isScanning = false
            self.isSessionActive = false
            self.session = nil
            // 清除NFC訊息，取消時就不會顯示訊息了
            self.nfcMessage = nil
        }
    }
    
    func startScanning() {
        // 檢查會話是否已經在運行中
        guard !isSessionActive else {
            DispatchQueue.main.async {
                self.nfcMessage = "NFC 掃描已在進行中，請等待完成"
            }
            return
        }
        
        guard NFCNDEFReaderSession.readingAvailable else {
            self.nfcMessage = "NFC reading not available on this device"
            return
        }
        
        do {
            // 在創建新的會話前先釋放可能存在的舊會話
            if session != nil {
                session?.invalidate()
                session = nil
            }
            
            session = NFCNDEFReaderSession(delegate: self, queue: DispatchQueue.global(), invalidateAfterFirstRead: true)
            session?.alertMessage = "Hold your iPhone near the NFC tag to read transaction details"
            session?.begin()
            isScanning = true
            isSessionActive = true
        } catch {
            DispatchQueue.main.async {
                self.nfcMessage = "啟動 NFC 掃描時發生錯誤: \(error.localizedDescription)"
                self.isScanning = false
                self.isSessionActive = false
            }
        }
    }
    // MARK: - NFC Writing
    func startWriting(recipient: String, merchant: String, amount: String, coinType: String = "SUI") { // Added merchant parameter
        // 檢查會話是否已經在運行中
        guard !isSessionActive else {
            DispatchQueue.main.async {
                self.nfcMessage = "NFC 操作已在進行中，請等待完成"
            }
            return
        }
        
        guard NFCNDEFReaderSession.readingAvailable else {
            self.nfcMessage = "NFC not available on this device"
            return
        }
        
        do {
            // 在創建新的會話前先釋放可能存在的舊會話
            if session != nil {
                session?.invalidate()
                session = nil
            }
            
            let payloadString = "recipient=\(recipient)&merchant=\(merchant)&amount=\(amount)&coinType=\(coinType)" // Added merchant to payload
            writePayload = payloadString
            session = NFCNDEFReaderSession(delegate: self, queue: DispatchQueue.global(), invalidateAfterFirstRead: false)
            session?.alertMessage = "Hold your iPhone near the NFC tag to write transaction info"
            session?.begin()
            isScanning = true
            isSessionActive = true
        } catch {
            DispatchQueue.main.async {
                self.nfcMessage = "啟動 NFC 寫入時發生錯誤: \(error.localizedDescription)"
                self.isScanning = false
                self.isSessionActive = false
            }
        }
    }

    // 新增: 使用SDK執行交易
    func executeTransaction(recipient: String, amount: String, coinType: String = "SUI") {
        guard let blockchainService = blockchainService else {
            DispatchQueue.main.async {
                self.nfcMessage = "區塊鏈服務未初始化，無法執行交易"
                self.transactionStatus = "failed"
            }
            return
        }
        
        // 檢查錢包地址
        if blockchainService.walletAddress.isEmpty {
            DispatchQueue.main.async {
                self.nfcMessage = "請先登入 zkLogin 錢包再執行交易"
                self.transactionStatus = "failed"
            }
            return
        }
        
        // 檢查地址格式
        guard recipient.starts(with: "0x") else {
            DispatchQueue.main.async {
                self.nfcMessage = "收款地址格式錯誤，須以0x開頭"
                self.transactionStatus = "failed"
            }
            return
        }
        
        // 檢查金額
        guard let amountValue = Double(amount), amountValue > 0 else {
            DispatchQueue.main.async {
                self.nfcMessage = "金額必須大於0"
                self.transactionStatus = "failed"
            }
            return
        }
        
        DispatchQueue.main.async {
            self.nfcMessage = "正在準備交易..."
            self.transactionStatus = "preparing"
        }
        
        // 建立交易物件
        guard let transaction = blockchainService.constructTransaction(
            recipientAddress: recipient,
            amount: amountValue,
            coinType: coinType
        ) else {
            DispatchQueue.main.async {
                self.nfcMessage = "建立交易失敗: \(blockchainService.errorMessage ?? "未知錯誤")"
                self.transactionStatus = "failed"
            }
            return
        }
        
        DispatchQueue.main.async {
            self.nfcMessage = "正在驗證並簽署交易..."
            self.transactionStatus = "signing"
        }
        
        // 驗證並簽署交易
        blockchainService.authenticateAndSignTransaction(transaction: transaction) { success, message in
            DispatchQueue.main.async {
                if success, let txId = message {
                    self.nfcMessage = "交易成功發送! 交易ID: \(txId)"
                    self.transactionStatus = "completed"
                    self.transactionId = txId
                    
                    // 驗證交易是否真實存在於區塊鏈上
                    self.verifyTransactionExistence(txId: txId)
                } else {
                    self.nfcMessage = "交易失敗: \(message ?? "未知錯誤")"
                    self.transactionStatus = "failed"
                }
            }
        }
    }
    
    // 新增: 驗證交易是否真實存在於區塊鏈上
    private func verifyTransactionExistence(txId: String) {
        guard let blockchainService = blockchainService else {
            return
        }
        
        DispatchQueue.main.async {
            self.nfcMessage = "正在區塊鏈上驗證交易..."
        }
        
        // 等待2秒後再驗證，確保交易有時間傳播到區塊鏈
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            blockchainService.verifyTransaction(transactionId: txId) { verified, message in
                DispatchQueue.main.async {
                    if verified {
                        self.nfcMessage = "交易已在區塊鏈上確認! 交易ID: \(txId)"
                        
                        // 生成區塊鏈瀏覽器連結
                        if let explorerURL = blockchainService.getTransactionExplorerURL(transactionId: txId) {
                            print("交易瀏覽器連結: \(explorerURL.absoluteString)")
                        }
                    } else {
                        self.nfcMessage = "警告: \(message ?? "交易可能尚未被區塊鏈確認，請稍後再檢查")"
                    }
                }
            }
        }
    }

    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        // 檢查是否已經標記為成功寫入，或是用戶主動取消的常見錯誤
        let userCanceledErrorMessages = ["Session invalidated by user", "User canceled", "操作被取消"]
        let errorMessage = error.localizedDescription
        
        // 系統資源不可用的特定錯誤處理
        let isResourceUnavailable = errorMessage.contains("System resource unavailable")
        
        // 如果已經設置了成功消息或者是用戶取消的情況，不要覆蓋為錯誤消息
        let isUserCancellation = userCanceledErrorMessages.contains { errorMessage.contains($0) }
        
        DispatchQueue.main.async {
            self.isScanning = false
            self.isSessionActive = false
            
            // 用戶取消時，清除所有狀態與訊息
            if isUserCancellation {
                self.resetNFCState()
                return
            }
            
            // 只有在尚未設置成功消息且不是用戶取消的情況下，才設置錯誤消息
            if !(self.nfcMessage?.contains("success") == true) {
                if isResourceUnavailable {
                    self.nfcMessage = "NFC 系統資源暫時不可用，請確認 NFC 功能已啟用且稍後再試"
                    print("⚠️ NFC 系統資源暫時不可用，可能需要重啟應用或設備")
                } else {
                    self.nfcMessage = errorMessage
                }
            } else if self.writePayload != nil {
                // 如果我們剛剛在嘗試寫入，可能是寫入成功但會話仍然被關閉
                // 在這種情況下保持可能已經設置的成功消息，或設置一個通用的成功消息
                if self.nfcMessage == nil || !self.nfcMessage!.contains("success") {
                    self.nfcMessage = "標籤寫入成功"
                }
                self.writePayload = nil
            }
            
            // 確保會話被正確釋放
            self.session = nil
        }
    }
    
    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        guard let message = messages.first,
              let record = message.records.first else {
            DispatchQueue.main.async {
                self.nfcMessage = nil  // 設置為 nil 而不是錯誤訊息
                self.isScanning = false
                self.isSessionActive = false
            }
            session.invalidate()  // 不傳送錯誤訊息
            return
        }
        
        // Handle different record types
        var payload: String = ""
        
        switch record.typeNameFormat {
        case .nfcWellKnown:
            // Specifically handle RTD_TEXT (Well Known Type "T")
            if record.type == Data("T".utf8) {
                guard !record.payload.isEmpty else {
                    session.invalidate(errorMessage: "NFC 文字記錄酬載為空。")
                    return
                }
                let statusByte = record.payload[0]
                let langCodeLength = Int(statusByte & 0x3F) // 低6位元組是語言代碼長度

                let textPayloadStartIndex = 1 + langCodeLength
                guard record.payload.count >= textPayloadStartIndex else {
                    session.invalidate(errorMessage: "NFC 文字記錄酬載格式錯誤（長度不足）。")
                    return
                }
                
                let textData = record.payload.subdata(in: textPayloadStartIndex..<record.payload.count)
                if let payloadString = String(data: textData, encoding: .utf8) {
                    payload = payloadString
                } else {
                    session.invalidate(errorMessage: "無法解碼 NFC 文字資料 (UTF-8)。")
                    return
                }
            } else {
                // 處理其他非預期的 Well Known Types
                let typeString = String(data: record.type, encoding: .utf8) ?? "未知類型"
                print("⚠️ 讀取到非預期的 NFC Well Known Type: \\(typeString)")
                session.invalidate(errorMessage: "不支援的 NFC 標籤內容（非文字記錄）。")
                return
            }
        case .absoluteURI:
            if let payloadString = String(data: record.payload, encoding: .utf8) {
                payload = payloadString
            } else {
                session.invalidate(errorMessage: "無法解碼 NFC URI 資料 (UTF-8)。")
                return
            }
            
        case .media:
            if let payloadString = String(data: record.payload, encoding: .utf8) {
                payload = payloadString
            } else {
                // 解碼失敗時不顯示錯誤訊息
                DispatchQueue.main.async {
                    self.resetNFCState() // 維持原有的重置邏輯
                    // resetNFCState 會將 nfcMessage 設為 nil，如果需要特定訊息，要在之後設定
                    // self.nfcMessage = "無法解碼 NFC Media Type 資料" // 例如
                }
                session.invalidate()
                return
            }
            
        default:
            // 不支援的格式時不顯示錯誤訊息
            DispatchQueue.main.async {
                self.resetNFCState() // 維持原有的重置邏輯
            }
            session.invalidate()
            return
        }
        
        // Successfully read the payload, now parse it
        print("ℹ️ 提取用於解析的酬載: \"\\(payload)\"")
        parseTransactionData(from: payload)
        
        // Close the session with success message but不顯示持續的訊息
        session.alertMessage = "Transaction data read successfully"
        session.invalidate()
    }
    
    private func parseTransactionData(from payload: String) {
        // Example format: "recipient=MerchantName&merchant=ItemName&amount=10.5&coinType=SUI" // Updated example format
        // 首先檢查 payload 是否為空
        guard !payload.isEmpty else {
            DispatchQueue.main.async {
                self.transactionData = nil
                // 清除訊息而不是顯示錯誤
                self.resetNFCState()
            }
            return
        }
        
        // 添加日誌以便調試
        print("🔍 NFC Payload: \(payload)")
        
        // 更強健的解析方法
        var data = [String: String]()
        var hasValidData = false
        
        // 1. 嘗試標準格式解析 (recipient=xxx&merchant=yyy&amount=zzz&coinType=aaa) // Updated comment
        let standardPairs = payload.components(separatedBy: "&")
        for pair in standardPairs {
            let elements = pair.components(separatedBy: "=")
            if elements.count == 2 {
                let key = elements[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let value = elements[1].trimmingCharacters(in: .whitespacesAndNewlines)
                
                if !key.isEmpty && !value.isEmpty {
                    data[key] = value
                    hasValidData = true
                    print("✅ 解析鍵值對: \(key)=\(value)")
                }
            }
        }
        
        // 2. 如果沒有找到標準格式的資料，嘗試查找任何可能的收款地址格式 (現在是商家名稱)
        // 注意：由於 recipient 現在是商家名稱，原先的 0x 地址正則表達式可能不再適用或需要調整。
        // 這裡我們假設商家名稱不需要特定格式檢查，如果需要，請告知。
        if !hasValidData || data["recipient"] == nil {
            // 這裡可以根據商家名稱的可能格式添加備用解析邏輯
            // 例如，如果 payload 中直接包含商家名稱，沒有 "recipient=" 前綴
            // 但為了保持與寫入格式一致，我們主要依賴標準解析。
            print("ℹ️ 未通過標準格式找到 recipient (商家名稱)")
        }

        // 新增: 嘗試查找商品名稱
        if !hasValidData || data["merchant"] == nil {
            // 這裡可以根據商品名稱的可能格式添加備用解析邏輯
            print("ℹ️ 未通過標準格式找到 merchant (商品名稱)")
        }
        
        // 3. 嘗試查找金額
        if !hasValidData || data["amount"] == nil {
            // 查找數字格式 (可能帶小數點)
            let amountPattern = "\\b\\d+(\\.\\d+)?\\b"
            if let amountMatch = payload.range(of: amountPattern, options: .regularExpression) {
                let amount = String(payload[amountMatch])
                data["amount"] = amount
                hasValidData = true
                print("✅ 通過正則表達式找到金額: \(amount)")
            }
        }
        
        // 4. 如果找不到幣種，設定預設值為 SUI
        if data["coinType"] == nil {
            data["coinType"] = "SUI"
            print("ℹ️ 未找到幣種，使用預設值: SUI")
        }
        
        DispatchQueue.main.async {
            // 日誌記錄解析結果
            print("📊 解析結果:")
            for (key, value) in data {
                print("   \\(key): \\(value)")
            }
            
            if hasValidData {
                self.transactionData = data
                let missingRecipient = data["recipient"] == nil
                let missingMerchant = data["merchant"] == nil
                let missingAmount = data["amount"] == nil

                if !missingRecipient && !missingMerchant && !missingAmount {
                    // 所有必要欄位都存在
                    // 根據現有邏輯，成功時不顯示持續訊息
                    self.nfcMessage = nil 
                    print("✅ NFC 標籤讀取成功且資料完整")
                } else {
                    // 資料存在但缺少關鍵欄位
                    var missingFieldsArray: [String] = []
                    if missingRecipient { missingFieldsArray.append("商家名稱") }
                    if missingMerchant { missingFieldsArray.append("商品名稱") }
                    if missingAmount { missingFieldsArray.append("金額") }
                    let missingFieldsText = missingFieldsArray.joined(separator: ", ")
                    
                    print("❌ 缺少關鍵欄位: \\(missingFieldsText)")
                    self.nfcMessage = "NFC 標籤資料不完整，缺少: \\(missingFieldsText)"
                }
            } else {
                // 沒有找到任何有效的鍵值對
                self.transactionData = nil
                print("❌ 無法解析 NFC 標籤內容")
                self.nfcMessage = "無法解析 NFC 標籤內容"
            }
            self.isScanning = false
            self.isSessionActive = false
        }
    }
    
    @available(iOS 13.0, *)
    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        guard let tag = tags.first else {
            // 標籤不存在時不顯示錯誤
            DispatchQueue.main.async {
                self.resetNFCState()
            }
            session.invalidate()
            return
        }

        session.connect(to: tag) { error in
        if let error = error {
            // 連接錯誤時不顯示錯誤訊息
            DispatchQueue.main.async {
                self.resetNFCState()
            }
            session.invalidate()
            return
        }

        tag.queryNDEFStatus { status, capacity, error in
            if let error = error {
                // 查詢狀態錯誤時不顯示錯誤訊息
                DispatchQueue.main.async {
                    self.resetNFCState()
                }
                session.invalidate()
                return
            }

            switch status {
            case .notSupported:
                // 不支援NDEF時不顯示錯誤訊息
                DispatchQueue.main.async {
                    self.resetNFCState()
                }
                session.invalidate()

            case .readOnly:
                // 只讀標籤時不顯示錯誤訊息
                DispatchQueue.main.async {
                    self.resetNFCState()
                }
                session.invalidate()

            case .readWrite:
                if let payloadString = self.writePayload {
                    // Always use Well Known Text type for writing
                    // Construct a valid RTD_TEXT payload manually for maximum compatibility
                    let lang = "en"
                    let langBytes = Array(lang.utf8)
                    let textBytes = Array(payloadString.utf8)
                    let statusByte = UInt8(langBytes.count)
                    var payload: [UInt8] = [statusByte]
                    payload.append(contentsOf: langBytes)
                    payload.append(contentsOf: textBytes)
                    let payloadData = Data(payload)
                    let textPayload = NFCNDEFPayload(
                        format: .nfcWellKnown,
                        type: Data([0x54]), // "T"
                        identifier: Data(),
                        payload: payloadData
                    )
                    let message = NFCNDEFMessage(records: [textPayload])
                    tag.writeNDEF(message) { error in
                        DispatchQueue.main.async {
                            self.isScanning = false
                            self.writePayload = nil
                            self.isSessionActive = false
                        }
                        if let error = error {
                            // 寫入錯誤時不顯示持續的錯誤訊息
                            DispatchQueue.main.async {
                                self.resetNFCState()
                            }
                            session.invalidate()
                        } else {
                            // 寫入成功，顯示一個簡短的成功訊息然後結束
                            session.alertMessage = "Successfully wrote to NFC tag"
                            session.invalidate()
                            // 在主線程更新UI狀態，但不設置持續的訊息
                            DispatchQueue.main.async {
                                print("Write success: \(payloadString)")
                                // 寫入成功後不顯示持續的訊息
                                self.nfcMessage = "標籤寫入成功" // Changed from nil
                            }
                        }
                    }
                } else {
                    // 如果是讀取流程
                    tag.readNDEF { message, error in
                        if let error = error {
                            session.invalidate(errorMessage: "Read error: \(error.localizedDescription)")
                            return
                        }

                        guard let message = message else {
                            session.invalidate(errorMessage: "No NDEF message found")
                            return
                        }

                        // Process the message
                        self.readerSession(session, didDetectNDEFs: [message])
                    }
                }

            @unknown default:
                // 未知狀態時不顯示錯誤訊息
                DispatchQueue.main.async {
                    self.resetNFCState()
                }
                session.invalidate()
            }
        }
    }
}
}