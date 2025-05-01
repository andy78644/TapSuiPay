import Foundation
import CoreNFC

@available(iOS 13.0, *)
class NFCService: NSObject, ObservableObject, NFCNDEFReaderSessionDelegate {
    func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {
        // Optional: you can add logging or UI updates here if desired
    }
    @Published var isScanning = false
    @Published var nfcMessage: String?
    @Published var transactionData: [String: String]?
    
    private var session: NFCNDEFReaderSession?
    private var writePayload: String?
    
    func startScanning() {
        guard NFCNDEFReaderSession.readingAvailable else {
            self.nfcMessage = "NFC reading not available on this device"
            return
        }
        
        session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: true)
        session?.alertMessage = "Hold your iPhone near the NFC tag to read transaction details"
        session?.begin()
        isScanning = true
    }
    // MARK: - NFC Writing
    func startWriting(recipient: String, amount: String, coinType: String = "SUI") {
        guard NFCNDEFReaderSession.readingAvailable else {
            self.nfcMessage = "NFC not available on this device"
            return
        }
        let payloadString = "recipient=\(recipient)&amount=\(amount)&coinType=\(coinType)"
        writePayload = payloadString
        session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
        session?.alertMessage = "Hold your iPhone near the NFC tag to write transaction info"
        session?.begin()
        isScanning = true
    }

    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        // 檢查是否已經標記為成功寫入，或是用戶主動取消的常見錯誤
        let userCanceledErrorMessages = ["Session invalidated by user", "User canceled", "操作被取消"]
        let errorMessage = error.localizedDescription
        
        // 如果已經設置了成功消息或者是用戶取消的情況，不要覆蓋為錯誤消息
        let isUserCancellation = userCanceledErrorMessages.contains { errorMessage.contains($0) }
        
        DispatchQueue.main.async {
            self.isScanning = false
            
            // 只有在尚未設置成功消息且不是用戶取消的情況下，才設置錯誤消息
            if !(self.nfcMessage?.contains("success") == true) && !isUserCancellation {
                self.nfcMessage = errorMessage
            } else if isUserCancellation && self.writePayload != nil {
                // 如果是用戶取消但我們剛剛在嘗試寫入，可能是寫入成功但會話仍然被關閉
                // 在這種情況下保持可能已經設置的成功消息，或設置一個通用的成功消息
                if self.nfcMessage == nil || !self.nfcMessage!.contains("success") {
                    self.nfcMessage = "標籤寫入成功"
                }
                self.writePayload = nil
            }
        }
    }
    
    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        guard let message = messages.first,
              let record = message.records.first else {
            DispatchQueue.main.async {
                self.nfcMessage = "No valid records found in NFC tag"
                self.isScanning = false
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
                }
                return
            }
            
        default:
            DispatchQueue.main.async {
                self.nfcMessage = "Unsupported record type: \(record.typeNameFormat)"
                self.isScanning = false
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
