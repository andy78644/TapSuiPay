import Foundation
import LocalAuthentication
import AuthenticationServices
import WebKit
import GoogleSignIn
// 使用我们自己的MockSuiKit实现
// import SuiKit

class SUIBlockchainService: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    @Published var walletAddress: String = ""
    @Published var transactionStatus: Transaction.TransactionStatus = .pending
    @Published var transactionId: String?
    @Published var errorMessage: String?
    @Published var isAuthenticating: Bool = false
    
    private var provider: SuiProvider?
    private var wallet: Wallet?
    private var signer: RawSigner?
    private var zkLoginSession: ASWebAuthenticationSession?
    private var ephemeralKeyPair: KeyPair?
    private var userSalt: String?
    private var jwtToken: String?
    
    // Keys for storing data in UserDefaults
    private let saltKey = "zkLoginUserSalt"
    private let addressKey = "zkLoginUserAddress"
    
    override init() {
        super.init()
        setupSuiProvider()
        loadUserData()
        
        // Register for URL callback notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleURLCallback(_:)),
            name: Notification.Name("HandleURLCallback"),
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handleURLCallback(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let url = userInfo["url"] as? URL else {
            return
        }
        
        print("SUIBlockchainService received URL callback: \(url)")
        handleAuthCallback(url: url)
    }
    
    private func setupSuiProvider() {
        do {
            // Initialize SUI provider with mainnet
            provider = SuiProvider(network: .mainnet)
            
            // If we have a stored address, we'll use it
            // Otherwise, we'll need to authenticate with zkLogin
            if walletAddress.isEmpty {
                // We'll initialize the wallet after zkLogin authentication
            } else {
                // For testing purposes, we can create a wallet
                // In production, this would use the zkLogin credentials
                try initializeWallet()
            }
        } catch {
            errorMessage = "Failed to initialize SUI provider: \(error.localizedDescription)"
        }
    }
    
    private func loadUserData() {
        // Load user salt and address from UserDefaults
        if let salt = UserDefaults.standard.string(forKey: saltKey) {
            userSalt = salt
        }
        
        if let address = UserDefaults.standard.string(forKey: addressKey) {
            walletAddress = address
        }
    }
    
    private func saveUserData() {
        // Save user salt and address to UserDefaults
        if let salt = userSalt {
            UserDefaults.standard.set(salt, forKey: saltKey)
        }
        
        if !walletAddress.isEmpty {
            UserDefaults.standard.set(walletAddress, forKey: addressKey)
        }
    }
    
    private func initializeWallet() throws {
        // In a real app, this would use zkLogin credentials
        // For now, we'll create a new wallet for testing
        print("创建新钱包...")
        wallet = try Wallet()
        if let account = wallet?.accounts.first, let provider = provider {
            print("钱包创建成功，设置账户...")
            signer = RawSigner(account: account, provider: provider)
            walletAddress = try account.address().description
            print("钱包地址设置为: \(walletAddress)")
        } else {
            print("❌ 钱包创建失败: 无法获取账户")
            throw NSError(domain: "SUIBlockchainService", code: 1001, 
                         userInfo: [NSLocalizedDescriptionKey: "无法创建钱包账户"])
        }
    }
    
    // MARK: - zkLogin Authentication
    
    func startZkLoginAuthentication() {
        isAuthenticating = true
        
        // Generate ephemeral key pair for zkLogin
        do {
            ephemeralKeyPair = try KeyPair()
            
            // If we don't have a salt yet, generate one
            if userSalt == nil {
                userSalt = generateRandomSalt()
            }
            
            // Start OAuth flow with Google - Proper configuration for zkLogin
            // Generate a secure nonce for CSRF protection
            let nonce = generateSecureRandomString(length: 32)
            
            // Google OAuth configuration - Using a simpler approach
            let clientId = "179459479770-aeoaa73k7savslnhbrru749l8jqcno6q.apps.googleusercontent.com"
            
            // 修正重定向URI格式
            let redirectURI = "com.googleusercontent.apps.179459479770-aeoaa73k7savslnhbrru749l8jqcno6q:/oauth2redirect"
            let encodedRedirectURI = redirectURI.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? redirectURI
            
            // 修正auth URL的格式和参数
            let authURL = "https://accounts.google.com/o/oauth2/v2/auth"
            + "?client_id=\(clientId)"
            + "&redirect_uri=\(encodedRedirectURI)"
            + "&response_type=code"
            + "&scope=email%20profile%20openid"
            + "&state=\(nonce)"
            + "&prompt=select_account"
            
            // Clear cookies to ensure fresh login each time
            let dataStore = WKWebsiteDataStore.default()
            dataStore.fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
                dataStore.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
                                     for: records.filter { $0.displayName.contains("google") },
                                     completionHandler: {})
            }
            
            // Print the full auth URL for debugging
            print("Auth URL: \(authURL)")
            
            // 修正回调URL scheme
            zkLoginSession = ASWebAuthenticationSession(
                url: URL(string: authURL)!,
                callbackURLScheme: "com.googleusercontent.apps.179459479770-aeoaa73k7savslnhbrru749l8jqcno6q",
                completionHandler: { [weak self] callbackURL, error in
                    guard let self = self else { return }
                    
                    if let error = error {
                        DispatchQueue.main.async {
                            self.errorMessage = "Authentication failed: \(error.localizedDescription)"
                            self.isAuthenticating = false
                        }
                        return
                    }
                    
                    if let callbackURL = callbackURL {
                        self.handleAuthCallback(url: callbackURL)
                    }
                }
            )
            
            zkLoginSession?.presentationContextProvider = self
            zkLoginSession?.start()
            
        } catch {
            errorMessage = "Failed to start authentication: \(error.localizedDescription)"
            isAuthenticating = false
        }
    }
    
    // 添加登出功能
    func signOut() {
        // 登出Google账号
        GIDSignIn.sharedInstance.signOut()
        
        // 清除本地存储的钱包信息
        walletAddress = ""
        userSalt = nil
        jwtToken = nil
        
        // 移除UserDefaults中保存的数据
        UserDefaults.standard.removeObject(forKey: saltKey)
        UserDefaults.standard.removeObject(forKey: addressKey)
        
        // 清理钱包实例
        wallet = nil
        signer = nil
        
        print("✅ 用户已成功登出")
    }
    
    private func handleAuthCallback(url: URL) {
        print("Handling auth callback with URL: \(url)")
        
        // For debugging - print the entire URL
        print("Full callback URL: \(url.absoluteString)")
        
        // 无论回调URL如何，我们都会完成登录流程
        // 在真实环境中应该验证URL参数，但为了测试目的，我们直接模拟成功
        print("⚠️ 跳过URL验证，直接模拟成功登录...")
        
        // 设置一个模拟的JWT token用于演示
        self.jwtToken = "mock_jwt_token_" + generateSecureRandomString(length: 10)
        
        // 继续完成登录流程
        DispatchQueue.main.async {
            print("开始模拟zkLogin完成过程...")
            self.simulateZkLoginCompletion()
        }
    }
    
    private func simulateZkLoginCompletion() {
        print("Simulating zkLogin completion...")
        
        // 注意：以下是zkLogin的模拟流程，实际应用中应该进行真实的zkLogin认证
        // 真实流程应该包括：
        // 1. 获取Google JWT token
        // 2. 生成一个临时密钥对
        // 3. 将JWT和盐值发送到zkLogin证明服务
        // 4. 获取zkLogin证明
        // 5. 使用证明在SUI网络上创建账户
        
        // 生成用户盐值，如果尚未存在
        if userSalt == nil {
            userSalt = generateRandomSalt()
            print("生成新的用户盐值: \(userSalt!)")
        }
        
        // 直接设置一个模拟的钱包地址（真实应用中应从zkLogin证明中派生）
        let mockAddress = "0x" + generateSecureRandomString(length: 40)
        self.walletAddress = mockAddress
        print("设置模拟钱包地址: \(mockAddress)")
        
        // 保存到UserDefaults
        saveUserData()
        
        // 打印成功信息
        print("✅ zkLogin authentication successful")
        print("📝 Wallet address: \(walletAddress)")
        print("🔑 User salt: \(userSalt ?? "none")")
        
        // 让UI有时间更新显示钱包地址
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // 完成身份验证过程
            self.isAuthenticating = false
            
            // 发送通知，让TransactionViewModel知道登录完成
            NotificationCenter.default.post(
                name: Notification.Name("AuthenticationCompleted"),
                object: nil
            )
        }
    }
    
    // MARK: - ASWebAuthenticationPresentationContextProviding
    
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Return the key window for presenting the authentication session
        return ASPresentationAnchor()
    }
    
    // MARK: - Transaction Methods
    
    func constructTransaction(recipientAddress: String, amount: Double, coinType: String = "SUI") -> Transaction? {
        guard !walletAddress.isEmpty else {
            errorMessage = "Sender wallet address not available"
            return nil
        }
        
        guard !recipientAddress.isEmpty, amount > 0 else {
            errorMessage = "Invalid recipient address or amount"
            return nil
        }
        
        return Transaction(
            recipientAddress: recipientAddress,
            amount: amount,
            senderAddress: walletAddress,
            coinType: coinType
        )
    }
    
    func authenticateAndSignTransaction(transaction: Transaction, completion: @escaping (Bool, String?) -> Void) {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            DispatchQueue.main.async {
                self.errorMessage = "Face ID not available: \(error?.localizedDescription ?? "Unknown error")"
                completion(false, self.errorMessage)
            }
            return
        }
        
        let reason = "Authenticate to sign transaction of \(transaction.amount) SUI to \(transaction.recipientAddress)"
        
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { [weak self] success, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if success {
                    self.submitTransaction(transaction: transaction, completion: completion)
                } else {
                    self.errorMessage = "Authentication failed: \(error?.localizedDescription ?? "Unknown error")"
                    completion(false, self.errorMessage)
                }
            }
        }
    }
    
    private func submitTransaction(transaction: Transaction, completion: @escaping (Bool, String?) -> Void) {
        guard let provider = provider, let signer = signer else {
            errorMessage = "SUI wallet not initialized"
            completion(false, errorMessage)
            return
        }
        
        self.transactionStatus = .inProgress
        
        Task {
            do {
                // Create transaction block
                var tx = try TransactionBlock()
                
                // Convert amount to MIST (SUI's smallest unit, 1 SUI = 10^9 MIST)
                let amountInMist = UInt64(transaction.amount * 1_000_000_000)
                
                // Split coin from gas and transfer to recipient
                let coin = try tx.splitCoin(
                    tx.gas,
                    [try tx.pure(value: .number(amountInMist))]
                )
                
                // Transfer the split coin to the recipient
                try tx.transferObjects(
                    [coin],
                    SuiAddress(transaction.recipientAddress)
                )
                
                // Sign and execute the transaction
                var result = try await signer.signAndExecuteTransaction(transactionBlock: &tx)
                
                // Wait for transaction confirmation
                result = try await provider.waitForTransaction(tx: result.digest)
                
                // Update transaction status
                DispatchQueue.main.async {
                    self.transactionStatus = .completed
                    self.transactionId = result.digest
                    completion(true, result.digest)
                }
            } catch {
                DispatchQueue.main.async {
                    self.transactionStatus = .failed
                    self.errorMessage = "Transaction failed: \(error.localizedDescription)"
                    completion(false, self.errorMessage)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func generateRandomSalt() -> String {
        // Generate a random salt for zkLogin using secure random method
        return generateSecureRandomString(length: 32)
    }
    
    private func generateSecureRandomString(length: Int) -> String {
        // Generate a cryptographically secure random string
        var randomBytes = [UInt8](repeating: 0, count: length)
        let result = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        
        if result == errSecSuccess {
            // Convert to hex string
            return randomBytes.map { String(format: "%02x", $0) }.joined()
        } else {
            // Fallback method if secure random fails
            let characters = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
            return String((0..<length).map { _ in characters.randomElement()! })
        }
    }
    
    // Helper function to decode JWT token
    private func decodeJWT(jwtToken jwt: String) -> [String: Any]? {
        let segments = jwt.components(separatedBy: ".")
        
        if segments.count > 1 {
            let base64String = segments[1]
                .replacingOccurrences(of: "-", with: "+")
                .replacingOccurrences(of: "_", with: "/")
            
            let padded = base64String.padding(
                toLength: ((base64String.count + 3) / 4) * 4,
                withPad: "=",
                startingAt: 0)
            
            if let data = Data(base64Encoded: padded),
               let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                return json
            }
        }
        
        return nil
    }
}
