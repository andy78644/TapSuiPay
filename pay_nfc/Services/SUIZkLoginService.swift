import Foundation
import AuthenticationServices
// import SuiKit
import GoogleSignIn
import CryptoKit
import JWTDecode
import WebKit

class SUIZkLoginService: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    @Published var walletAddress: String = ""
    @Published var isAuthenticating: Bool = false
    @Published var errorMessage: String?
    
    // zkLogin配置
    private let network: NetworkType = .testnet

    
    // 存储在UserDefaults中的键
    private let saltKey = "zkLoginUserSalt"
    private let addressKey = "zkLoginUserAddress"
    private let jwtKey = "zkLoginJWT"
    private let ephemeralKey = "zkLoginEphemeralKey"
    
    // zkLogin会话和数据
    private var zkLoginSession: ASWebAuthenticationSession?
    private var ephemeralKeyPair: KeyPair?
    private var userSalt: String?
    private var jwtToken: String?
    private var maxEpoch: UInt64?
    private var suiProvider: SuiProvider?
    
    override init() {
        super.init()
        self.suiProvider = SuiProvider(network: network)
        self.loadUserData()
        
        // 注册URL回调通知
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
    
    // MARK: - 公共方法
    
    /// 开始zkLogin认证流程
    func startZkLoginAuthentication() {
        isAuthenticating = true
        
        do {
            // 1. 生成临时密钥对
            ephemeralKeyPair = try KeyPair()
            guard let ephemeralKeyPair = ephemeralKeyPair else {
                throw NSError(domain: "SUIZkLogin", code: 1001, userInfo: [NSLocalizedDescriptionKey: "无法生成临时密钥对"])
            }
            
            // 将私钥保存到UserDefaults（实际应用中应更安全地存储）
            let privateKeyHex = ephemeralKeyPair.privateKey // privateKey本身已经是String类型
            UserDefaults.standard.set(privateKeyHex, forKey: ephemeralKey)
            
            // 2. 获取当前的epoch信息，用于设置zkLogin有效期
            Task {
                do {
                    guard let suiProvider = suiProvider else {
                        throw NSError(domain: "SUIZkLogin", code: 1002, userInfo: [NSLocalizedDescriptionKey: "SUI Provider未初始化"])
                    }
                    
                    // 获取系统状态
                    let response = try await suiProvider.getSuiSystemState()
                    guard let systemState = response.result else {
                        throw NSError(domain: "SUIZkLogin", code: 1002, userInfo: [NSLocalizedDescriptionKey: "无法获取系统状态"])
                    }
                    
                    self.maxEpoch = systemState.epoch + 10 // 设置10个epoch的有效期
                    print("当前Epoch: \(systemState.epoch), 设置最大有效期Epoch: \(String(describing: self.maxEpoch))")
                    
                    // 3. 获取或生成用户盐值
                    if self.userSalt == nil {
                        self.userSalt = self.generateRandomSalt()
                        UserDefaults.standard.set(self.userSalt, forKey: self.saltKey)
                    }
                    
                    // 4. 获取zkLogin nonce，用于防止重放攻击
                    let randomness = try self.generateSecureRandomData(length: 32)
                    let randomnessHex = randomness.map { String(format: "%02hhx", $0) }.joined()
                    
                    guard let maxEpoch = self.maxEpoch else {
                        throw NSError(domain: "SUIZkLogin", code: 1003, userInfo: [NSLocalizedDescriptionKey: "无法获取最大Epoch"])
                    }
                    
                    // 生成zkLogin nonce
                    // 注意：SuiKit可能尚未提供generateNonce方法的具体实现，这里使用占位符
                    // 实际应用中应替换为SuiKit中的对应方法
                    let ephemeralPublicKey = ephemeralKeyPair.publicKey // publicKey本身是String类型
                    let nonce = UUID().uuidString // 临时替代方案
                    
                    print("生成的zkLogin nonce: \(nonce)")
                    
                    // 5. 启动OAuth流程
                    DispatchQueue.main.async {
                        self.startGoogleAuthFlow(nonce: nonce)
                    }
                } catch {
                    print("获取Epoch信息失败: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.errorMessage = "无法获取区块链状态: \(error.localizedDescription)"
                        self.isAuthenticating = false
                    }
                }
            }
            
        } catch {
            print("启动zkLogin失败: \(error.localizedDescription)")
            self.errorMessage = "启动登录失败: \(error.localizedDescription)"
            self.isAuthenticating = false
        }
    }
    
    /// 登出并清除凭据
    func signOut() {
        // 登出Google账号
        GIDSignIn.sharedInstance.signOut()
        
        // 清除本地存储的信息
        walletAddress = ""
        userSalt = nil
        jwtToken = nil
        ephemeralKeyPair = nil
        
        // 移除UserDefaults中保存的数据
        UserDefaults.standard.removeObject(forKey: saltKey)
        UserDefaults.standard.removeObject(forKey: addressKey)
        UserDefaults.standard.removeObject(forKey: jwtKey)
        UserDefaults.standard.removeObject(forKey: ephemeralKey)
        
        print("✅ 用户已成功登出")
    }
    
    // MARK: - 私有方法
    
    /// 启动Google OAuth认证流程
    private func startGoogleAuthFlow(nonce: String) {
        guard let clientId = AppConfig.shared.clientId, let redirectUri = AppConfig.shared.redirectUri else {
            print("[配置错误] 缺少clientId或redirectUri")
            return
        }
        let encodedRedirectURI = redirectUri.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? redirectUri
        
        // 构建Google OAuth URL
        let authURL = "https://accounts.google.com/o/oauth2/v2/auth"
        + "?client_id=\(clientId)"
        + "&redirect_uri=\(encodedRedirectURI)"
        + "&response_type=code"
        + "&scope=openid%20email%20profile"
        + "&nonce=\(nonce)"
        + "&prompt=select_account"
        
        print("Auth URL: \(authURL)")
        
        // 清除旧的cookie
        let dataStore = WKWebsiteDataStore.default()
        dataStore.fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
            dataStore.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
                                 for: records.filter { $0.displayName.contains("google") },
                                 completionHandler: {})
        }
        
        // 启动OAuth会话
        zkLoginSession = ASWebAuthenticationSession(
            url: URL(string: authURL)!,
            callbackURLScheme: "com.googleusercontent.apps.179459479770-aeoaa73k7savslnhbrru749l8jqcno6q",
            completionHandler: { [weak self] callbackURL, error in
                guard let self = self else { return }
                
                if let error = error {
                    DispatchQueue.main.async {
                        self.errorMessage = "认证失败: \(error.localizedDescription)"
                        self.isAuthenticating = false
                    }
                    return
                }
                
                if let callbackURL = callbackURL {
                    print("收到回调URL: \(callbackURL)")
                    self.handleAuthCallback(url: callbackURL)
                }
            }
        )
        
        zkLoginSession?.presentationContextProvider = self
        zkLoginSession?.start()
    }
    
    /// 处理OAuth回调
    @objc private func handleURLCallback(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let url = userInfo["url"] as? URL else {
            return
        }
        
        print("SUIZkLoginService收到URL回调: \(url)")
        handleAuthCallback(url: url)
    }
    
    /// 处理认证回调URL
    private func handleAuthCallback(url: URL) {
        print("处理认证回调URL: \(url)")
        
        // 1. 从URL中提取 code
        guard let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = urlComponents.queryItems?.first(where: { $0.name == "code" })?.value else {
            print("❌ 无法从回调URL中提取 code")
            DispatchQueue.main.async {
                self.errorMessage = "认证失败：无法获取 code"
                self.isAuthenticating = false
            }
            return
        }
        print("✅ 成功提取 code: \(code.prefix(15))...")
        
        // 2. 用 code 换取 id_token 和 access_token
        guard let clientId = AppConfig.shared.clientId, let redirectUri = AppConfig.shared.redirectUri else {
            print("[配置错误] 缺少clientId或redirectUri")
            return
        }
        let tokenURL = URL(string: "https://oauth2.googleapis.com/token")!
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        let params = [
            "code": code,
            "client_id": clientId,
            "redirect_uri": redirectUri,
            "grant_type": "authorization_code"
        ]
        request.httpBody = params.map { "\($0.key)=\($0.value)" }.joined(separator: "&").data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ 获取Token失败: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.errorMessage = "认证失败：无法获取Token: \(error.localizedDescription)"
                    self.isAuthenticating = false
                }
                return
            }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                print("❌ Token响应解析失败")
                DispatchQueue.main.async {
                    self.errorMessage = "认证失败：Token响应解析失败"
                    self.isAuthenticating = false
                }
                return
            }
            let idToken = json["id_token"] as? String
            let accessToken = json["access_token"] as? String
            
            guard let token = idToken else {
                print("❌ 无法从Token响应中提取ID token")
                DispatchQueue.main.async {
                    self.errorMessage = "认证失败：无法获取ID token"
                    self.isAuthenticating = false
                }
                return
            }
            
            // 保存tokens
            self.jwtToken = token
            UserDefaults.standard.set(token, forKey: self.jwtKey)
            
            if let accessToken = accessToken {
                print("✅ 成功提取access token: \(accessToken.prefix(15))...")
                // 可以选择保存access token用于API调用
            }
            
            print("✅ 成功提取ID token: \(token.prefix(15))...")
            
            // 3. 完成zkLogin流程
            DispatchQueue.main.async {
                self.completeZkLogin(idToken: token)
            }
        }
        task.resume()
    }
    
    /// 完成zkLogin流程，获取zkProof并派生SUI地址
    private func completeZkLogin(idToken: String) {
        // --- SIMULATION MODE: bypass server, always succeed ---
        guard let salt = userSalt else {
            self.errorMessage = "无法获取zkLogin所需数据"
            self.isAuthenticating = false
            return
        }
        print("[模拟] 开始完成zkLogin流程... 使用盐值: \(salt)")
        // 1. 解析sub（模拟）
        let sub: String = "simulated_sub_123456"
        // 2. 生成假地址（可用真实sub+salt, 这里只是演示）
        let input = sub + salt
        let fakeAddr = "0x" + String(input.hashValue).replacingOccurrences(of: "-", with: "a").padding(toLength: 40, withPad: "f", startingAt: 0)
        // 3. 保存并广播
        DispatchQueue.main.async {
            self.walletAddress = fakeAddr
            UserDefaults.standard.set(fakeAddr, forKey: self.addressKey)
            print("✅ [模拟] zkLogin认证成功!")
            print("📝 [模拟] 钱包地址: \(self.walletAddress)")
            NotificationCenter.default.post(
                name: Notification.Name("AuthenticationCompleted"),
                object: nil
            )
            self.isAuthenticating = false
            self.errorMessage = nil
        }
        // --- END SIMULATION ---
        return
    }
    // --- 真实网络请求/zkProof逻辑已被移除（仅保留模拟） ---
    // 若需恢复真实zkLogin逻辑，请还原此处的网络和zkProof处理代码。

    
    /// 从UserDefaults加载用户数据
    private func loadUserData() {
        if let salt = UserDefaults.standard.string(forKey: saltKey) {
            userSalt = salt
        }
        
        if let address = UserDefaults.standard.string(forKey: addressKey) {
            walletAddress = address
        }
        
        if let jwt = UserDefaults.standard.string(forKey: jwtKey) {
            jwtToken = jwt
        }
    }
    
    /// 生成随机盐值
    private func generateRandomSalt() -> String {
        return generateSecureRandomString(length: 32)
    }
    
    /// 生成加密安全的随机字符串
    private func generateSecureRandomString(length: Int) -> String {
        let randomData = generateSecureRandomData(length: length / 2) // 每个字节产生2个十六进制字符
        return randomData.map { String(format: "%02x", $0) }.joined()
    }
    
    /// 生成加密安全的随机数据
    private func generateSecureRandomData(length: Int) -> Data {
        var randomBytes = [UInt8](repeating: 0, count: length)
        let result = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        
        if result == errSecSuccess {
            return Data(randomBytes)
        } else {
            // 备用方法
            return Data((0..<length).map { _ in UInt8.random(in: 0...255) })
        }
    }
    
    // MARK: - ASWebAuthenticationPresentationContextProviding
    
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return ASPresentationAnchor()
    }
}

// MARK: - 辅助结构体

struct ZkProofResponse: Codable {
    let zkProof: String
    let inputs: [String]
    // 其他字段...
}

// 由于SUI Swift SDK可能没有完整实现zkLogin功能，我们添加一些辅助方法
// 注意：这些方法是模拟的，实际应用中需要根据真实SDK调整
class ZkLoginUtil {
    // SuiKit可能尚未提供zkLogin方法的具体实现，这里提供临时实现
    // 实际应用中应使用SuiKit提供的方法
    
    static func computeZkLoginAddressFromSeed(
        name: String,
        value: String,
        issuer: String,
        audience: String
    ) throws -> String {
        // 实际应用中，这里应该使用SDK的实现
        // 这里基于输入参数生成一个假地址作为示例
        let input = "\(name)\(value)\(issuer)\(audience)"
        let inputData = input.data(using: .utf8)!
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap { String(format: "%02x", $0) }.joined()
        
        return "0x\(hashString.prefix(40))"
    }
} 