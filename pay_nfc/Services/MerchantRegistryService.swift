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
            return "您的地址 \(address) 已註冊過商家名稱 \"\(existingName)\"。"
        case .storageError:
            return "儲存商家名稱時發生錯誤。"
        }
    }
}

class MerchantRegistryService: ObservableObject {
    private let userDefaultsKey = "com.zyra.paynfc.merchantNameMappings" // 使用您的 App Bundle ID

    // 儲存結構：[MerchantName: WalletAddress]
    private var merchantNameMappings: [String: String] {
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
        guard !merchantName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw MerchantRegistrationError.nameIsEmpty
        }

        // 檢查商家名稱是否已被其他地址註冊
        if let existingAddress = merchantNameMappings[merchantName], existingAddress.lowercased() != address.lowercased() {
            throw MerchantRegistrationError.nameAlreadyTaken(name: merchantName)
        }

        // 檢查該地址是否已註冊其他商家名稱
        for (name, registeredAddress) in merchantNameMappings {
            if registeredAddress.lowercased() == address.lowercased(), name.lowercased() != merchantName.lowercased() {
                throw MerchantRegistrationError.addressAlreadyRegistered(address: address, existingName: name)
            }
        }
        
        // 如果該地址已註冊相同的名稱，則視為成功 (無操作)
        if let existingAddress = merchantNameMappings[merchantName], existingAddress.lowercased() == address.lowercased() {
            print("商家 \(merchantName) 已由地址 \(address) 註冊，無需重複操作。")
            return
        }

        var updatedMappings = merchantNameMappings
        updatedMappings[merchantName] = address
        merchantNameMappings = updatedMappings
        print("商家 \(merchantName) 成功註冊到地址 \(address)")
    }

    // 根據地址獲取商家名稱
    func getMerchantName(for address: String) -> String? {
        for (name, registeredAddress) in merchantNameMappings {
            if registeredAddress.lowercased() == address.lowercased() {
                return name
            }
        }
        return nil
    }

    // 根據商家名稱獲取地址
    func getAddress(for merchantName: String) -> String? {
        return merchantNameMappings[merchantName]
    }
    
    // (可選) 清除特定地址的註冊
    func unregisterMerchant(for address: String) {
        var updatedMappings = merchantNameMappings
        let namesToRemove = updatedMappings.filter { $0.value.lowercased() == address.lowercased() }.map { $0.key }
        for name in namesToRemove {
            updatedMappings.removeValue(forKey: name)
        }
        merchantNameMappings = updatedMappings
    }

    // (可選) 清除所有註冊
    func clearAllRegistrations() {
        merchantNameMappings = [:]
    }
}
