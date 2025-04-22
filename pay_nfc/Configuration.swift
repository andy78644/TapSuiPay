import Foundation

// This file contains configuration settings for the app
struct AppConfiguration {
    // SUI blockchain network settings
    struct Blockchain {
        static let mainnetURL = "https://fullnode.mainnet.sui.io"
        static let testnetURL = "https://fullnode.testnet.sui.io"
        static let devnetURL = "https://fullnode.devnet.sui.io"
        
        // Default to testnet for development
        static let currentNetwork = testnetURL
    }
    
    // NFC tag format settings
    struct NFCTag {
        static let recipientKey = "recipient"
        static let amountKey = "amount"
    }
    
    // Authentication settings
    struct Auth {
        static let redirectScheme = "suipay"
        static let saltStorageKey = "zkLoginUserSalt"
        static let addressStorageKey = "zkLoginUserAddress"
    }
}
