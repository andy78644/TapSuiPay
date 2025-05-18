# Wallet Integration with SuiKit

## ✅ 已完成項目

### 1. 實作 ZkLoginWalletManager
- 在 `Services/ZkLoginWalletManager.swift` 中新增：
  - 屬性
    - ✅ `@Published var walletAddress: String`：綁定 UI 顯示錢包地址
    - ✅ `private var mapping: [String: String]`（userID → address）
  - 方法
    - ✅ `func signInWithGoogle()`：觸發 Google Sign-In，取得 `sub` 或 `userID`，呼叫 `getOrCreateWallet`
    - ✅ `func getOrCreateWallet(for userID: String) async throws`：
      1. ✅ 檢查 `mapping[userID]`：
         - 若存在：
           - ✅ 從 Keychain 讀取對應私鑰
           - ✅ 用私鑰重建 `Wallet` 或 `KeyPair`，取得地址
         - 否則：
           - ✅ 創建新的 `Wallet()`（SuiKit 實例）
           - ✅ 取出私鑰、地址
           - ✅ 把私鑰存入 Keychain，address 存入 `mapping[userID]` 並持久化（UserDefaults）
      2. ✅ 設定 `walletAddress = address`
    - ✅ `func signOut()`：清除 Keychain 中的私鑰與 `mapping[userID]` 或視需求保留

### 2. 私鑰與 Mapping 儲存策略
- ✅ 私鑰：存到 iOS Keychain（使用 `KeychainHelper` 實現）
- ✅ 映射：UserDefaults 字典（鍵名 `googleWalletMap`），內容為 `[userID: address]`

### 3. 整合到 DI/ServiceContainer
- ✅ 在 `Services/ServiceContainer.swift` 註冊 `ZkLoginWalletManager`
- ✅ 注入到 `SUIBlockchainService`、各 ViewModel

### 4. 更新 UI 層
- ✅ ViewModel 新增依賴 `ZkLoginWalletManager`
- ✅ `ContentView` 或 `MainView`：
  - ✅ Sign In / Sign Out 按鈕
  - ✅ 顯示 `walletAddress`
  - ✅ 監聽 `@Published` 更新

### 5. 區塊鏈服務整合
- ✅ 在 `TransactionViewModel` 中使用 `walletManager` 進行交易簽署
- ✅ 添加通知機制實現服務間通信

```mermaid
flowchart LR
    A[Sign In with Google] --> B[getOrCreateWallet(userID)]
    B --> C{mapping[userID] exists?}
    C -->|Yes| D[Load private key from Keychain]
    D --> E[Rebuild Wallet/KeyPair]
    E --> F[Set walletAddress]
    C -->|No| G[Create new Wallet()]
    G --> H[Extract private key & address]
    H --> I[Store private key in Keychain and mapping]
    I --> F
    F --> J[Done]
    subgraph SignOut Flow
      K[Sign Out] --> L[Clear Keychain & mapping]
    end
```

## 🚀 待辦項目

### 1. 單元測試
- ✅ 創建 `ZkLoginWalletManagerTests` 測試類
- 測試項目：
  - ✅ 同一 `userID` 多次執行 `getOrCreateWallet` 產出相同地址
  - ✅ signIn 並登出流程，Keychain 和映射是否正確
  - ✅ 不同用戶獲得不同地址
- 執行測試並修復發現的問題

### 2. 移除舊有 zkLogin 實現
一旦新的錢包系統穩定後：
- [ ] 審查 `SUIZkLoginService` 中已棄用的功能
- [ ] 逐步移除對舊版 zkLogin 的依賴
- [ ] 統一所有視圖模型使用 `walletManager`
- [ ] 清理未使用的代碼

### 3. 其他改進
- [ ] 添加錯誤處理和恢復機制
- [ ] 實現交易歷史記錄功能
- [ ] 實現錢包余額查詢功能
- [ ] 優化網絡切換功能
- [ ] 添加交易通知功能

### 4. 未來整合真實 zkLogin
- 當 SuiKit 提供 zkLogin KeyPair API 時，替換 `getOrCreateWallet` 中的 `Wallet()` 部分：
  - [ ] 呼叫真實 OAuth → 取得 JWT
  - [ ] 由 SuiKit API 生成 zkLogin 密鑰對與地址
  - [ ] 維持相同的映射表結構，確保無縫切換
  - [ ] 更新文檔和單元測試

---
最後更新：2025年5月17日
