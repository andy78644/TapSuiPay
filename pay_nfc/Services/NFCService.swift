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
        // Example format: "recipient=address123&amount=10.5"
        let pairs = payload.components(separatedBy: "&")
        var data = [String: String]()
        
        for pair in pairs {
            let elements = pair.components(separatedBy: "=")
            if elements.count == 2 {
                let key = elements[0]
                let value = elements[1]
                data[key] = value
            }
        }
        
        DispatchQueue.main.async {
            self.transactionData = data
            self.nfcMessage = "Transaction data read successfully"
            self.isScanning = false
        }
    }
    
    // iOS 13+ support for didDetectTags
    // @available(iOS 13.0, *)
    // func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
    //     guard let tag = tags.first else {
    //         session.invalidate(errorMessage: "No tag found")
    //         return
    //     }
        
    //     // Connect to the tag and read its NDEF message
    //     session.connect(to: tag) { error in
    //         if let error = error {
    //             session.invalidate(errorMessage: "Connection error: \(error.localizedDescription)")
    //             return
    //         }
            
    //         tag.queryNDEFStatus { status, capacity, error in
    //             if let error = error {
    //                 session.invalidate(errorMessage: "Query status error: \(error.localizedDescription)")
    //                 return
    //             }
                
    //             switch status {
    //             case .notSupported:
    //                 session.invalidate(errorMessage: "Tag is not NDEF compliant")
                    
    //             case .readOnly, .readWrite:
    //                 tag.readNDEF { message, error in
    //                     if let error = error {
    //                         session.invalidate(errorMessage: "Read error: \(error.localizedDescription)")
    //                         return
    //                     }
                        
    //                     guard let message = message else {
    //                         session.invalidate(errorMessage: "No NDEF message found")
    //                         return
    //                     }
                        
    //                     // Process the message
    //                     self.readerSession(session, didDetectNDEFs: [message])
    //                 }
                    
    //             @unknown default:
    //                 session.invalidate(errorMessage: "Unknown tag status")
    //             }
    //         }
    //     }
    // }
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
