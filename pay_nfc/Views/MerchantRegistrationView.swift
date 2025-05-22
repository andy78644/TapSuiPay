import SwiftUI

struct MerchantRegistrationView: View {
    @EnvironmentObject var merchantRegistryService: MerchantRegistryService
    @EnvironmentObject var blockchainService: SUIBlockchainService // 假設 SUIBlockchainService 包含錢包地址
    @Environment(\.presentationMode) var presentationMode

    @State private var merchantName: String = ""
    @State private var isLoading: Bool = false
    @State private var alertItem: AlertItem? // 使用您現有的 AlertItem 模型

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("註冊您的商店名稱")
                    .font(.title2)
                    .padding(.top)

                TextField("輸入商店名稱", text: $merchantName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                    .disabled(isLoading)

                if isLoading {
                    ProgressView("註冊中...")
                } else {
                    Button("註冊商店") {
                        Task {
                            await registerMerchant()
                        }
                    }
                    .padding()
                    .buttonStyle(.borderedProminent)
                    .disabled(merchantName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                }
                
                Spacer()
            }
            .navigationTitle("商店註冊")
            .navigationBarItems(leading: Button("取消") {
                presentationMode.wrappedValue.dismiss()
            })
            .alert(item: $alertItem) { item in
                Alert(title: Text(item.title), message: Text(item.message), dismissButton: .default(Text("好的"), action: {
                    if item.title == "註冊成功" {
                        presentationMode.wrappedValue.dismiss()
                    }
                }))
            }
        }
    }

    private func registerMerchant() async {
        isLoading = true
        
        guard blockchainService.isUserLoggedIn else {
            alertItem = AlertItem(title: "錯誤", message: MerchantRegistrationError.notLoggedIn.localizedDescription ?? "請先登入")
            isLoading = false
            return
        }

        // User is logged in, now check walletAddress
        // Since blockchainService.walletAddress is String, not String?,
        // we directly check if it's empty.
        let walletAddress = blockchainService.walletAddress
        guard !walletAddress.isEmpty else {
            // Logged in, but address is empty.
            alertItem = AlertItem(title: "錯誤", message: "無法獲取有效的錢包地址。請重新登入或檢查您的帳戶。")
            isLoading = false
            return
        }
        
        let nameToRegister = merchantName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !nameToRegister.isEmpty else {
            alertItem = AlertItem(title: "錯誤", message: MerchantRegistrationError.nameIsEmpty.localizedDescription ?? "商家名稱不可為空")
            isLoading = false
            return
        }

        // 模擬合約互動延遲
        try? await Task.sleep(nanoseconds: 2 * 1_000_000_000) // 2 秒延遲

        do {
            try merchantRegistryService.register(merchantName: nameToRegister, for: walletAddress)
            alertItem = AlertItem(title: "註冊成功", message: "商家 \"\(nameToRegister)\" 已成功註冊到您的地址。")
            // presentationMode.wrappedValue.dismiss() // Consider if dismiss should be here or in alert's action
        } catch let error as MerchantRegistrationError {
            alertItem = AlertItem(title: "註冊失敗", message: error.localizedDescription ?? "發生未知錯誤")
        } catch {
            alertItem = AlertItem(title: "註冊失敗", message: "發生未知錯誤: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
}

struct MerchantRegistrationView_Previews: PreviewProvider {
    static var previews: some View {
        // 確保 SUIZkLoginService 和 SUIBlockchainService 有預設的初始化方法或提供模擬實例
        let zkLoginService = SUIZkLoginService()
        let blockchainService = SUIBlockchainService(zkLoginService: zkLoginService)
        // 你可能需要給 blockchainService.walletAddress 一個預覽值
        // blockchainService.walletAddress = "0x123previewaddress"

        MerchantRegistrationView()
            .environmentObject(MerchantRegistryService())
            .environmentObject(blockchainService)
    }
}
