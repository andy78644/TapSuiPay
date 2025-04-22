import Foundation
import CoreNFC

@available(iOS 13.0, *)
class NFCService: NSObject, ObservableObject {
    @Published var isScanning = false
    @Published var nfcMessage: String?
    @Published var transactionData: [String: String]?
    
    private var session: NFCNDEFReaderSession?
    
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
}

// MARK: - NFCNDEFReaderSessionDelegate

extension NFCService: NFCNDEFReaderSessionDelegate {
    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        DispatchQueue.main.async {
            self.isScanning = false
            self.nfcMessage = error.localizedDescription
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
    @available(iOS 13.0, *)
    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        guard let tag = tags.first else {
            session.invalidate(errorMessage: "No tag found")
            return
        }
        
        // Connect to the tag and read its NDEF message
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
                    
                case .readOnly, .readWrite:
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
                    
                @unknown default:
                    session.invalidate(errorMessage: "Unknown tag status")
                }
            }
        }
    }
}
