import Foundation

// 註冊時可能發生的錯誤類型
enum MerchantRegistrationError: Error, LocalizedError {
    case notLoggedIn
    case nameIsEmpty
    case nameAlreadyTaken(name: String)
    case addressAlreadyRegistered(address: String, existingName: String)
    case storageError(Error?)

    var errorDescription: String? {
        switch self {
        case .notLoggedIn:
            return "請先登入 zkLogin 錢包。"
        case .nameIsEmpty:
            return "商家名稱不可為空。"
        case .nameAlreadyTaken(let name):
            return "商家名稱 \"\(name)\" 已被註冊。"
        case .addressAlreadyRegistered(let address, let existingName):
            return "您的地址 \(address) 已註冊過商家名稱 \"\(existingName)\"。一個地址只能註冊一個商家名稱。"
        case .storageError:
            return "儲存商家名稱時發生錯誤。"
        }
    }
}

class MerchantRegistryService: ObservableObject {
    // 使用新的 UserDefaults Key 以避免與舊資料格式衝突，並明確表示結構為 WalletAddress: MerchantName
    private let userDefaultsKey = "com.zyra.paynfc.userMerchantMappings.v2"

    // 儲存結構變更為：[WalletAddress: MerchantName]
    private var userMerchantData: [String: String] {
        get {
            UserDefaults.standard.dictionary(forKey: userDefaultsKey) as? [String: String] ?? [:]
        }
        set {
            UserDefaults.standard.set(newValue, forKey: userDefaultsKey)
            DispatchQueue.main.async {
                self.objectWillChange.send() // 通知 SwiftUI 視圖更新
            }
        }
    }

    // 註冊商家名稱
    func register(merchantName: String, for address: String) throws {
        let trimmedMerchantName = merchantName.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedAddress = address.lowercased()

        guard !trimmedMerchantName.isEmpty else {
            throw MerchantRegistrationError.nameIsEmpty
        }

        var currentData = userMerchantData

        // 1. 檢查此地址是否已註冊商家名稱
        if let existingName = currentData[normalizedAddress] {
            if existingName.lowercased() == trimmedMerchantName.lowercased() {
                // 相同地址註冊相同名稱，視為成功 (無操作)
                print("商家 \(trimmedMerchantName) 已由地址 \(address) 註冊，無需重複操作。")
                return
            } else {
                // 相同地址嘗試註冊不同名稱
                throw MerchantRegistrationError.addressAlreadyRegistered(address: address, existingName: existingName)
            }
        }

        // 2. 檢查商家名稱是否已被其他地址註冊 (假設商家名稱需要全域唯一)
        // 遍歷所有已註冊的商家，檢查名稱是否衝突
        for (mappedAddress, mappedName) in currentData {
            if mappedName.lowercased() == trimmedMerchantName.lowercased() && mappedAddress != normalizedAddress {
                throw MerchantRegistrationError.nameAlreadyTaken(name: trimmedMerchantName)
            }
        }
        
        // 執行註冊
        currentData[normalizedAddress] = trimmedMerchantName
        userMerchantData = currentData
        print("商家 \(trimmedMerchantName) 成功註冊到地址 \(normalizedAddress)")
    }

    // 根據地址獲取商家名稱
    func getMerchantName(for address: String) -> String? {
        return userMerchantData[address.lowercased()]
    }

    // 根據商家名稱獲取地址 (假設商家名稱是唯一的)
    func getAddress(for merchantName: String) -> String? {
        let lowercasedMerchantName = merchantName.lowercased()
        for (address, name) in userMerchantData {
            if name.lowercased() == lowercasedMerchantName {
                return address // 返回的是原始大小寫的地址 (如果需要，可以返回 normalizedAddress)
            }
        }
        return nil
    }
    
    // 清除特定地址的註冊
    func unregisterMerchant(for address: String) {
        var currentData = userMerchantData
        currentData.removeValue(forKey: address.lowercased())
        userMerchantData = currentData
        print("已清除地址 \(address) 的商家註冊。")
    }

    // 清除所有註冊
    func clearAllRegistrations() {
        userMerchantData = [:]
        print("已清除所有商家註冊。")
    }

    // (可選) 檢查特定商家名稱是否已被註冊
    func isMerchantNameTaken(_ merchantName: String) -> Bool {
        let lowercasedMerchantName = merchantName.lowercased()
        return userMerchantData.values.contains { $0.lowercased() == lowercasedMerchantName }
    }
}
