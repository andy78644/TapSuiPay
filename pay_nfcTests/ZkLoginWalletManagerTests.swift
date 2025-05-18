// ZkLoginWalletManagerTests.swift
// Unit tests for ZkLoginWalletManager
import Testing
@testable import pay_nfc

struct ZkLoginWalletManagerTests {
    private let testUser1 = "user1"
    private let testUser2 = "user2"
    // 原本使用 KeychainWrapper，改為 KeychainHelper
    // // 不再使用 KeychainWrapper，改用 KeychainHelper

    @Test
    func sameUserMultipleCallsYieldsSameAddress() async throws {
        // 清除 UserDefaults 映射與 Keychain
        UserDefaults.standard.removeObject(forKey: "googleWalletMap")
        try? keychain.removePassword(forService: "wallet_\(testUser1)")
        
        let manager = ZkLoginWalletManager()
        let addr1 = try await manager.getOrCreateWallet(for: testUser1)
        let addr2 = try await manager.getOrCreateWallet(for: testUser1)
        #assert(addr1 == addr2)
    }

    @Test
    func differentUsersGetDifferentAddresses() async throws {
        // 清除 UserDefaults 映射與 Keychain
        UserDefaults.standard.removeObject(forKey: "googleWalletMap")
        try? keychain.removePassword(forService: "wallet_\(testUser1)")
        try? keychain.removePassword(forService: "wallet_\(testUser2)")
        
        let manager = ZkLoginWalletManager()
        let addr1 = try await manager.getOrCreateWallet(for: testUser1)
        let addr2 = try await manager.getOrCreateWallet(for: testUser2)
        #assert(addr1 != addr2)
    }

    @Test
    func signOutClearsMappingAndKeychain() async throws {
        // 清除 UserDefaults 映射與 Keychain
        UserDefaults.standard.removeObject(forKey: "googleWalletMap")
        try? keychain.removePassword(forService: "wallet_\(testUser1)")

        let manager = ZkLoginWalletManager()
        // 產生資料並驗證存在
        let oldAddr = try await manager.getOrCreateWallet(for: testUser1)
        // 確認 keychain 有儲存
        let service = "wallet_\(testUser1)"
        var stored = try? keychain.password(forService: service)
        #assert(stored == keychain.password(forService: service))
        
        // 執行 signOut
        manager.signOut()
        // walletAddress 應清空
        #assert(manager.walletAddress.isEmpty)
        
        // 清除後呼叫 getOrCreateWallet 應產生新地址
        let newAddr = try await manager.getOrCreateWallet(for: testUser1)
        #assert(newAddr != oldAddr)
    }
}
