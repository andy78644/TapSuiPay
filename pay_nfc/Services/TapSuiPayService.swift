import Foundation
import SuiKit

/// Service for interacting with the TapSuiPay Move contract
class TapSuiPayService {
    // MARK: - Properties
    
    /// The transaction service for executing transactions
    private let transactionService: TransactionService
    
    /// The object ID of the MerchantRegistry shared object
    private let registryObjectId: String
    
    /// The package ID of the TapSuiPay Move package
    private let packageId: String
    
    // MARK: - Initialization
    
    /// Initialize with a transaction service and contract information
    init(transactionService: TransactionService, packageId: String, registryObjectId: String) {
        self.transactionService = transactionService
        self.packageId = packageId
        self.registryObjectId = registryObjectId
    }
    
    // MARK: - Contract Operations
    
    /// Registers as a merchant
    /// - Parameter name: The merchant name
    /// - Returns: The transaction digest
    func registerMerchant(name: String) async throws -> String {
        // Create transaction block
        var txb = try TransactionBlock()
        
        // Call the register_merchant function
        let _ = try txb.moveCall(
            target: "\(packageId)::tapsuipay::register_merchant",
            arguments: [
                txb.object(id: registryObjectId),
                txb.pure(Array(name.utf8))
            ]
        )
        
        // Execute the transaction
        return try await transactionService.executeTransaction(transactionBlock: txb)
    }
    
    /// Makes a payment to a merchant
    /// - Parameters:
    ///   - merchantName: The name of the merchant
    ///   - amount: The payment amount in MIST
    ///   - productInfo: Information about the product being purchased
    /// - Returns: The transaction digest
    func makePayment(merchantName: String, amount: UInt64, productInfo: String) async throws -> String {
        // Create transaction block
        var txb = try TransactionBlock()
        
        // Split the payment amount from the gas coin
        let payment = try txb.splitCoin(txb.gas, [txb.pure(value: .number(amount))])
        
        // Call the purchase function
        let _ = try txb.moveCall(
            target: "\(packageId)::tapsuipay::purchase",
            arguments: [
                txb.object(id: registryObjectId),
                txb.pure(Array(merchantName.utf8)),
                txb.pure(Array(productInfo.utf8)),
                payment
            ]
        )
        
        // Execute the transaction
        return try await transactionService.executeTransaction(transactionBlock: txb)
    }
    
    /// Gets the address of a merchant
    /// - Parameter name: The merchant name
    /// - Returns: The merchant address
    func getMerchantAddress(name: String) async throws -> String {
        // Create a transaction block for the query
        var txb = try TransactionBlock()
        
        // Call the get_merchant_address function
        let result = try txb.moveCall(
            target: "\(packageId)::tapsuipay::get_merchant_address",
            arguments: [
                txb.object(id: registryObjectId),
                txb.pure(Array(name.utf8))
            ]
        )
        
        // Get the provider from the transaction service
        let provider = SuiProvider(network: .testnet)
        
        // Execute the transaction block in read-only mode to get the result
        let response = try await provider.devInspectTransaction(
            txb: txb,
            sender: try SuiAddress.fromHex(await provider.getReferenceGasPrice())
        )
        
        // Parse the result - the address will be in the returned data
        if let returnValues = response.results,
           !returnValues.isEmpty,
           let returnValue = returnValues.first?.returnValues?.first,
           case let .address(address) = returnValue {
            return address
        }
        
        throw TapSuiPayError.merchantNotFound
    }
    
    /// Checks if a merchant exists
    /// - Parameter name: The merchant name
    /// - Returns: True if the merchant exists
    func merchantExists(name: String) async throws -> Bool {
        // Create a transaction block for the query
        var txb = try TransactionBlock()
        
        // Call the merchant_exists function
        let result = try txb.moveCall(
            target: "\(packageId)::tapsuipay::merchant_exists",
            arguments: [
                txb.object(id: registryObjectId),
                txb.pure(Array(name.utf8))
            ]
        )
        
        // Get the provider from the transaction service
        let provider = SuiProvider(network: .testnet)
        
        // Execute the transaction block in read-only mode to get the result
        let response = try await provider.devInspectTransaction(
            txb: txb,
            sender: try SuiAddress.fromHex(await provider.getReferenceGasPrice())
        )
        
        // Parse the result - the boolean will be in the returned data
        if let returnValues = response.results,
           !returnValues.isEmpty,
           let returnValue = returnValues.first?.returnValues?.first,
           case let .bool(exists) = returnValue {
            return exists
        }
        
        throw TapSuiPayError.queryFailed
    }
    
    /// Updates a merchant's address
    /// - Parameters:
    ///   - name: The merchant name
    ///   - newAddress: The new merchant address
    /// - Returns: The transaction digest
    func updateMerchantAddress(name: String, newAddress: String) async throws -> String {
        // Create transaction block
        var txb = try TransactionBlock()
        
        // Call the update_merchant_address function
        let _ = try txb.moveCall(
            target: "\(packageId)::tapsuipay::update_merchant_address",
            arguments: [
                txb.object(id: registryObjectId),
                txb.pure(Array(name.utf8)),
                txb.pure(value: .address(try AccountAddress.fromHex(newAddress)))
            ]
        )
        
        // Execute the transaction
        return try await transactionService.executeTransaction(transactionBlock: txb)
    }
}

// MARK: - Custom Errors

enum TapSuiPayError: Error {
    case merchantNotFound
    case merchantNameTaken
    case notMerchantOwner
    case invalidMerchantName
    case invalidProductInfo
    case invalidAmount
    case queryFailed
}
