import Foundation

struct Transaction: Codable {
    let recipientAddress: String
    let amount: Double
    let senderAddress: String
    var transactionId: String?
    var status: TransactionStatus = .pending
    
    enum TransactionStatus: String, Codable {
        case pending
        case inProgress
        case completed
        case failed
    }
}
