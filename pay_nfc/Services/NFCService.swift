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
    func startWriting(recipient: String, amount: String, coinType: String = "SUI") {
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
            
            let payloadString = "recipient=\(recipient)&amount=\(amount)&coinType=\(coinType)"
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
            
            // 只有在尚未設置成功消息且不是用戶取消的情況下，才設置錯誤消息
            if !(self.nfcMessage?.contains("success") == true) && !isUserCancellation {
                if isResourceUnavailable {
                    self.nfcMessage = "NFC 系統資源暫時不可用，請確認 NFC 功能已啟用且稍後再試"
                    print("⚠️ NFC 系統資源暫時不可用，可能需要重啟應用或設備")
                } else {
                    self.nfcMessage = errorMessage
                }
            } else if isUserCancellation && self.writePayload != nil {
                // 如果是用戶取消但我們剛剛在嘗試寫入，可能是寫入成功但會話仍然被關閉
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
                self.nfcMessage = "No valid records found in NFC tag"
                self.isScanning = false
                self.isSessionActive = false
            }
            return
        }
        
        // Handle different record types
        var payload: String = ""
        
        switch record.typeNameFormat {
        case .absoluteURI, .nfcWellKnown:
            // Skip first byte (length of the status byte) for Well Known type
            let payloadData: Data
            if record.typeNameFormat == .nfcWellKnown {
                payloadData = record.payload.advanced(by: 1)
            } else {
                payloadData = record.payload
            }
            
            if let payloadString = String(data: payloadData, encoding: .utf8) {
                payload = payloadString
            } else {
                DispatchQueue.main.async {
                    self.nfcMessage = "Could not decode payload as UTF-8"
                    self.isScanning = false
                    self.isSessionActive = false
                }
                return
            }
            
        case .media:
            if let payloadString = String(data: record.payload, encoding: .utf8) {
                payload = payloadString
            } else {
                DispatchQueue.main.async {
                    self.nfcMessage = "Could not decode media payload as UTF-8"
                    self.isScanning = false
                    self.isSessionActive = false
                }
                return
            }
            
        default:
            DispatchQueue.main.async {
                self.nfcMessage = "Unsupported record type: \(record.typeNameFormat)"
                self.isScanning = false
                self.isSessionActive = false
            }
            return
        }
        
        // Successfully read the payload, now parse it
        parseTransactionData(from: payload)
        
        // Close the session with success message
        session.alertMessage = "Transaction data read successfully"
        session.invalidate()
    }
    
    private func parseTransactionData(from payload: String) {
        // Example format: "recipient=address123&amount=10.5&coinType=SUI"
        // 首先檢查 payload 是否為空
        guard !payload.isEmpty else {
            DispatchQueue.main.async {
                self.transactionData = nil
                self.nfcMessage = "讀取到空白內容，請確認 NFC 標籤已正確寫入資料"
                self.isScanning = false
                self.isSessionActive = false
            }
            return
        }
        
        // 添加日誌以便調試
        print("🔍 NFC Payload: \(payload)")
        
        // 更強健的解析方法
        var data = [String: String]()
        var hasValidData = false
        
        // 1. 嘗試標準格式解析 (recipient=xxx&amount=yyy&coinType=zzz)
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
        
        // 2. 如果沒有找到標準格式的資料，嘗試查找任何可能的收款地址格式
        if !hasValidData || data["recipient"] == nil {
            // 嘗試查找 0x 開頭的地址字符串，這通常是一個 SUI 地址
            if let addressMatch = payload.range(of: "0x[0-9a-fA-F]{40,}", options: .regularExpression) {
                let address = String(payload[addressMatch])
                data["recipient"] = address
                hasValidData = true
                print("✅ 通過正則表達式找到收款地址: \(address)")
            }
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
                print("   \(key): \(value)")
            }
            
            if hasValidData {
                self.transactionData = data
                
                // 檢查是否包含必要的交易資訊
                let hasMissingFields = data["recipient"] == nil || data["amount"] == nil
                if !hasMissingFields {
                    self.nfcMessage = "Transaction data read successfully"
                } else {
                    // 資料存在但缺少關鍵欄位
                    let missingFields = [
                        data["recipient"] == nil ? "recipient" : nil,
                        data["amount"] == nil ? "amount" : nil
                    ].compactMap { $0 }.joined(separator: ", ")
                    
                    self.nfcMessage = "讀取到不完整的交易資料，缺少: \(missingFields)，請確認 NFC 標籤格式"
                    print("❌ 缺少關鍵欄位: \(missingFields)")
                }
            } else {
                // 沒有找到任何有效的鍵值對
                self.transactionData = nil
                self.nfcMessage = "無法辨識的交易資料格式: \(payload)"
                print("❌ 無法解析 NFC 標籤內容")
            }
            self.isScanning = false
            self.isSessionActive = false
        }
    }
    
    @available(iOS 13.0, *)
    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        guard let tag = tags.first else {
            session.invalidate(errorMessage: "No tag found")
            return
        }

        session.connect(to: tag) { error in
        if let error = error {
            session.invalidate(errorMessage: "Connection error: \(error.localizedDescription)")
            return
        }

        tag.queryNDEFStatus { status, capacity, error in
            if let error = error {
                session.invalidate(errorMessage: "Query status error: \(error.localizedDescription)")
                return
            }

            switch status {
            case .notSupported:
                session.invalidate(errorMessage: "Tag is not NDEF compliant")

            case .readOnly:
                session.invalidate(errorMessage: "Tag is read-only and cannot be written")

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
                            session.invalidate(errorMessage: "Write error: \(error.localizedDescription)")
                            DispatchQueue.main.async {
                                self.nfcMessage = "Write error: \(error.localizedDescription)"
                            }
                        } else {
                            session.alertMessage = "Successfully wrote to NFC tag"
                            session.invalidate()
                            DispatchQueue.main.async {
                                self.nfcMessage = "Write success: \(payloadString)"
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
                session.invalidate(errorMessage: "Unknown tag status")
            }
        }
    }
}
}
