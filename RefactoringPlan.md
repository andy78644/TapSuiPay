# Refactoring Plan: SUI NFC Pay Blockchain Integration

## 1. Current System Analysis

From examining the repository, we have identified the following components:
- `SUIBlockchainService.swift`: Main blockchain service with zkLogin integration
- `SuiKitIntegration.swift`: Simulated zkLogin service for testing
- `SUIZkLoginService.swift`: zkLogin authentication
- `MockSuiKit.swift`: Mock implementation for testing
- Transaction handling in various places

## 2. Requirements for Refactoring

1. **Create a direct SuiKit integration**:
   - Replace the current zkLogin authentication with direct wallet creation
   - Create a single wallet per device with ED25519 keys (most common for Sui)
   - Store wallet information securely on the device
   - Protect the private key with FaceID/TouchID

2. **Blockchain transaction integration**:
   - Support Move contract calls to the TapSuiPay contract
   - Provide functionality for merchant registration and payments
   - Handle transaction building, signing, and sending

3. **Google Sign-in**:
   - Maintain Google sign-in but make it passive
   - Don't integrate it with blockchain operations

## 3. Progress Update

### Completed ✅

1. **Core Components**
   - Created `KeychainManager.swift` for secure wallet storage with biometric protection
   - Implemented `WalletManager.swift` for wallet operations (create, delete, get address)
   - Built `TransactionService.swift` for blockchain interaction
   - Created `TapSuiPayService.swift` for contract-specific operations
   - Added `GoogleAuthService.swift` for passive Google Sign-in

2. **Integration**
   - Updated `ServiceContainer.swift` to include new services
   - Refactored `TransactionViewModel.swift` to use the new wallet system
   - Updated UI components in `MainView.swift` and `TransactionStateView.swift`
   - Added `GoogleSignInView.swift` for Google account management

3. **Testing**
   - Created unit tests for `WalletManager` and `TransactionService`

### In Progress 🔄

1. **Testing**
   - Complete end-to-end testing of the new wallet flow
   - Test biometric authentication with real devices

### Pending ⏳

1. **Documentation**
   - Update app documentation to reflect the new wallet system
   - Add user guide for using the new wallet flow

## 3. Implementation Components

### 3.1 Wallet Management

**`WalletManager.swift`**
- Core functionality:
  ```swift
  // Create a new wallet
  func createWallet() throws -> Wallet
  
  // Import wallet from mnemonic
  func importWallet(mnemonic: String) throws -> Wallet
  
  // Get current wallet
  func getCurrentWallet() throws -> Wallet?
  
  // Get wallet address
  func getWalletAddress() throws -> String
  ```

- Based on SuiKit implementation:
  ```swift
  // Creating a new wallet with ED25519 keys
  let wallet = try Wallet()
  
  // Creating a wallet from mnemonic
  let mnemonic = try Mnemonic(mnemonic: phrase.components(separatedBy: " "))
  let wallet = try Wallet(mnemonic: mnemonic)
  
  // Access wallet address
  let address = try wallet.accounts[0].address()
  ```

### 3.2 Secure Storage

**`KeychainManager.swift`**
- Store private key securely with biometric protection
- Implementation approach:
  ```swift
  // Store wallet with biometric protection
  func storeWallet(_ wallet: Wallet) throws
  
  // Retrieve wallet with biometric authentication
  func retrieveWallet() throws -> Wallet?
  
  // Check if wallet exists
  func walletExists() -> Bool
  ```

- Using FaceID/TouchID with LocalAuthentication:
  ```swift
  let context = LAContext()
  var error: NSError?
  
  if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
      context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                           localizedReason: "Authenticate to access your wallet") { success, error in
          // Handle authentication result
      }
  }
  ```

### 3.3 Transaction Handling

**`TransactionService.swift`**
- Build and execute transactions using the Sui blockchain:
  ```swift
  // Send SUI to an address
  func transferSUI(amount: UInt64, to: String) async throws -> String
  
  // Build and execute a custom transaction
  func executeTransaction(transactionBlock: TransactionBlock) async throws -> String
  
  // Sign a transaction block
  func signTransaction(transactionBlock: TransactionBlock) throws -> Signature
  ```

- Based on SuiKit implementation:
  ```swift
  // Create transaction block
  var tx = try TransactionBlock()
  
  // Create signer and provider
  let provider = SuiProvider(network: .testnet)
  let signer = RawSigner(account: wallet.accounts[0], provider: provider)
  
  // Execute transaction
  let result = try await signer.signAndExecuteTransaction(transactionBlock: &tx)
  ```

### 3.4 TapSuiPay Contract Integration

**`TapSuiPayService.swift`**
- Implement contract-specific operations:
  ```swift
  // Register as a merchant
  func registerMerchant(name: String) async throws -> String
  
  // Make payment to merchant
  func makePayment(merchantName: String, amount: UInt64, productInfo: String) async throws -> String
  
  // Get merchant information
  func getMerchantAddress(name: String) async throws -> String
  ```

- Based on the Move contract:
  ```swift
  // Register merchant transaction
  var tx = try TransactionBlock()
  let _ = try tx.moveCall(
      target: "tapsuipay_move::tapsuipay::register_merchant",
      arguments: [
          tx.object(id: registryObjectId),
          tx.pure(Array("MerchantName".utf8))
      ]
  )
  
  // Purchase transaction
  var tx = try TransactionBlock()
  let payment = try tx.splitCoin(tx.gas, [tx.pure(amount)])
  let _ = try tx.moveCall(
      target: "tapsuipay_move::tapsuipay::purchase",
      arguments: [
          tx.object(id: registryObjectId),
          tx.pure(Array(merchantName.utf8)),
          tx.pure(Array(productInfo.utf8)),
          payment
      ]
  )
  ```

### 3.5 Google Authentication Service

**`GoogleAuthService.swift`**
- Maintain basic Google authentication:
  ```swift
  // Sign in with Google
  func signIn() async throws -> GIDGoogleUser
  
  // Sign out
  func signOut()
  
  // Check if user is signed in
  var isSignedIn: Bool { get }
  ```

## 4. Integration Flow

1. **App Startup**:
   - Check if wallet exists in secure storage
   - If wallet exists, prompt for biometric authentication to unlock it
   - If no wallet exists, show options to create or import wallet

2. **Wallet Creation**:
   - Generate new wallet with SuiKit
   - Display and allow user to save mnemonic phrase securely
   - Store wallet in Keychain with biometric protection

3. **Transaction Flow**:
   - User initiates transaction (payment to merchant)
   - App requests biometric authentication to access private key
   - Build transaction using SuiKit and contract-specific functions
   - Sign and submit transaction
   - Display transaction result and status

4. **Google Sign-in Flow**:
   - Maintain as a separate identity layer
   - Store Google user ID but don't use it for blockchain operations

## 5. Security Considerations

1. **Private Key Protection**:
   - Store private keys in Keychain with access control using biometrics
   - Clear private key from memory after use
   - Implement timeouts for key availability

2. **Recovery Mechanism**:
   - Allow mnemonic backup during wallet creation
   - Support wallet recovery using mnemonic phrases
   - Warn users to store mnemonic securely

3. **Transaction Safety**:
   - Confirm transaction details before signing
   - Show clear information about gas fees and total amounts
   - Allow cancellation of transactions

## 6. Testing Plan

1. **Unit Tests**:
   - Test wallet creation, storage, and retrieval
   - Test transaction building and signing
   - Test contract integration functions

2. **Integration Tests**:
   - Test complete transaction flows on testnet
   - Test biometric protection flow
   - Test Google authentication integration

## 7. Implementation Checklist

- [x] Create `WalletManager.swift` for wallet creation and management
- [x] Create `KeychainManager.swift` for secure wallet storage
- [x] Create `TransactionService.swift` for transaction operations
- [x] Create `TapSuiPayService.swift` for contract integration
- [x] Create `GoogleAuthService.swift` for passive Google sign-in
- [x] Update UI to support new wallet creation/import flow
- [x] Update transaction UI to work with new services
- [x] Add biometric authentication prompts
- [x] Write unit tests for wallet and transaction operations
- [x] Remove legacy zkLogin components
- [x] Clean up unused code and dependencies

## 8. Migration Notes

- No user data migration was needed (fresh start)
- Legacy zkLogin code has been removed
- New wallet system implemented successfully with SuiKit
- UI updated to work with the new direct wallet integration
- Google sign-in implemented as optional, separate feature
