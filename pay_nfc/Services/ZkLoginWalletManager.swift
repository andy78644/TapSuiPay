// filepath: Services/ZkLoginWalletManager.swift
import Foundation
import Combine
import UIKit
import GoogleSignIn

/// 管理基於 Google Sign-In 的 zkLogin 錢包
class ZkLoginWalletManager: ObservableObject {
    @Published var walletAddress: String = ""
    @Published var isAuthenticating: Bool = false
    @Published var errorMessage: String?
    
    private var mapping: [String: String]
    private let mappingKey = "googleWalletMap"
    // 不再使用 KeychainWrapper，改用 KeychainHelper
    // private let keychain = KeychainWrapper()
    
    init() {
        // 從 UserDefaults 加載已有的映射
        self.mapping = UserDefaults.standard.dictionary(forKey: mappingKey) as? [String: String] ?? [:]
    }
    
    /// 根據 userID 獲取或創建錢包地址
    func getOrCreateWallet(for userID: String) async throws -> String {
        if let address = mapping[userID] {
            walletAddress = address
            return address
        }
        
        // 創建新的 KeyPair 和 Account
        let keyPair = try KeyPair()
        let account = try Account(keyPair: keyPair)
        let address = try account.address().description
        
        // 保存私鑰至 Keychain
        let service = serviceForUserID(userID)
        try KeychainHelper.set(keyPair.privateKey, service: service)
        
        // 更新映射並持久化
        mapping[userID] = address
        UserDefaults.standard.set(mapping, forKey: mappingKey)
        
        walletAddress = address
        return address
    }
    
    /// 登出並清除所有憑據
    func signOut() {
        // 清除 Keychain 中的私鑰
        for userID in mapping.keys {
            let service = serviceForUserID(userID)
            try? KeychainHelper.remove(service)
        }
        
        // 清空映射
        mapping.removeAll()
        UserDefaults.standard.removeObject(forKey: mappingKey)
        
        // 清除當前地址
        walletAddress = ""
    }
    
    private func serviceForUserID(_ userID: String) -> String {
        return "wallet_\(userID)"
    }
}

extension ZkLoginWalletManager {
    /// 使用 Google Sign-In 進行身份驗證並獲取 userID
    func signInWithGoogle() {
        isAuthenticating = true
        guard let clientId = AppConfig.shared.clientId else {
            errorMessage = "無效的 clientId"
            isAuthenticating = false
            return
        }
        // 設定 global Configuration
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientId)
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            errorMessage = "無法獲取 rootViewController"
            isAuthenticating = false
            return
        }
        // 使用 Async/Await API
        Task {
            do {
                let signInResult = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)
                let userID = signInResult.user.userID ?? ""
                let address = try await self.getOrCreateWallet(for: userID)
                DispatchQueue.main.async {
                    self.walletAddress = address
                    NotificationCenter.default.post(name: Notification.Name("AuthenticationCompleted"), object: nil)
                    self.isAuthenticating = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.isAuthenticating = false
                }
            }
        }
    }
}
