import Foundation

// This is a mock implementation of SuiKit to avoid the "no such module 'SuiKit'" error
// In a real implementation, you would integrate the actual SuiKit package

// MARK: - Mock SuiKit Types

enum NetworkType {
    case mainnet
    case testnet
    case devnet
    case localnet
}

class SuiProvider {
    let network: NetworkType
    
    init(network: NetworkType = .mainnet) {
        self.network = network
    }
    
    func waitForTransaction(tx: String) async throws -> TransactionResult {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 2_000_000_000)
        return TransactionResult(digest: tx, status: "success")
    }
    
    // 添加兼容SUIZkLoginService的方法
    func getSuiSystemState() async throws -> SystemStateResponse {
        // 模拟系统状态返回
        return SystemStateResponse(result: SystemState(epoch: 123))
    }
}

struct TransactionResult {
    let digest: String
    let status: String
}

class KeyPair {
    enum KeyScheme {
        case ED25519
        case SECP256K1
        case SECP256R1
    }
    
    private let scheme: KeyScheme
    let privateKey: String
    let publicKey: String
    
    init(keyScheme: KeyScheme = .ED25519) throws {
        self.scheme = keyScheme
        // Generate random keys for demo
        self.privateKey = String((0..<64).map { _ in "0123456789abcdef".randomElement()! })
        self.publicKey = String((0..<64).map { _ in "0123456789abcdef".randomElement()! })
    }
    
    func getPublicKey() -> PublicKey {
        return PublicKey(key: publicKey, scheme: scheme)
    }
}

struct PublicKey: CustomStringConvertible {
    let key: String
    let scheme: KeyPair.KeyScheme
    
    var description: String {
        return key
    }
}

class Account {
    private let keyPair: KeyPair
    
    init(keyPair: KeyPair) {
        self.keyPair = keyPair
    }
    
    func address() throws -> SuiAddress {
        // Generate a mock address based on the public key
        let publicKey = keyPair.getPublicKey().description
        let prefix = publicKey.prefix(10)
        return SuiAddress("0x\(prefix)")
    }
}

struct SuiAddress: CustomStringConvertible {
    let address: String
    
    // Single initializer to avoid ambiguity
    init(_ address: String) {
        self.address = address
    }
    
    var description: String {
        return address
    }
}

class Wallet {
    let accounts: [Account]
    
    init() throws {
        // Create a random account
        let keyPair = try KeyPair()
        self.accounts = [Account(keyPair: keyPair)]
    }
}

class RawSigner {
    let account: Account
    let provider: SuiProvider
    
    init(account: Account, provider: SuiProvider) {
        self.account = account
        self.provider = provider
    }
    
    func signAndExecuteTransaction(transactionBlock: inout TransactionBlock) async throws -> TransactionResult {
        // Simulate transaction execution
        try await Task.sleep(nanoseconds: 1_000_000_000)
        let txId = "0x" + String((0..<64).map { _ in "0123456789abcdef".randomElement()! })
        return TransactionResult(digest: txId, status: "pending")
    }
}

class TransactionBlock {
    let gas: String = "gas"
    
    init() throws {
        // Initialize transaction block
    }
    
    func splitCoin(_ gas: String, _ amounts: [TransactionArgument]) throws -> TransactionArgument {
        // Mock split coin operation
        return TransactionArgument.object("splitCoin_result")
    }
    
    func pure(value: TransactionValue) throws -> TransactionArgument {
        // Mock pure value
        return TransactionArgument.pure(value)
    }
    
    func transferObjects(_ objects: [TransactionArgument], _ recipient: SuiAddress) throws {
        // Mock transfer objects operation
    }
}

indirect enum TransactionArgument {
    case pure(TransactionValue)
    case object(String)
    case input(TransactionArgument)
}

enum TransactionValue {
    case string(String)
    case number(UInt64)
}

// 添加系统状态响应结构体
struct SystemStateResponse {
    let result: SystemState?
}

struct SystemState {
    let epoch: UInt64
    // 其他属性可以根据需要添加
}

// 添加 ZkLoginUtil 類別
class ZkLoginUtil {
    static func computeZkLoginAddress(
        claimName: String,
        claimValue: String,
        audience: String,
        userSalt: String
    ) throws -> String {
        // 這是一個模擬實現，用於開發/測試
        // 實際應用中應使用 SuiKit 的真實方法
        let input = "\(claimName):\(claimValue):\(audience):\(userSalt)"
        let inputData = input.data(using: .utf8)!
        let hash = SHA256.hash(data: inputData)
        let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
        
        return "0x\(hashString.prefix(40))"
    }
    
    // 添加與示例匹配的 jwtToAddress 方法
    static func jwtToAddress(jwt: String, userSalt: String) throws -> String {
        // 解析 JWT 獲取必要信息
        guard let jwt = try? decode(jwt: jwt) else {
            throw NSError(domain: "ZkLoginUtil", code: 1001, userInfo: [NSLocalizedDescriptionKey: "無法解析 JWT"])
        }
        
        // 獲取 sub 和 aud 值
        guard let sub = jwt.claim(name: "sub").string else {
            throw NSError(domain: "ZkLoginUtil", code: 1002, userInfo: [NSLocalizedDescriptionKey: "JWT 缺少 sub 字段"])
        }
        
        // 獲取 audience (aud)，可能是字串或陣列
        var audience = ""
        if let aud = jwt.claim(name: "aud").string {
            audience = aud
        } else if let auds = jwt.claim(name: "aud").array as? [String], let firstAud = auds.first {
            audience = firstAud
        } else {
            throw NSError(domain: "ZkLoginUtil", code: 1003, userInfo: [NSLocalizedDescriptionKey: "JWT 缺少有效的 aud 字段"])
        }
        
        // 計算地址
        let input = "sub:\(sub):\(audience):\(userSalt)"
        let inputData = input.data(using: .utf8)!
        let hash = SHA256.hash(data: inputData)
        let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
        
        return "0x\(hashString.prefix(40))"
    }
}

// 添加 decode 函數，用於 MockSuiKit 內部使用
func decode(jwt: String) throws -> JWT {
    return try JWTDecode.decode(jwt: jwt)
}

// 添加簡易的 SHA256 支持 (如果需要)
import CryptoKit
import JWTDecode // 添加 JWTDecode 依賴
