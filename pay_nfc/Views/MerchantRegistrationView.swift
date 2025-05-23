import SwiftUI
import LocalAuthentication // 匯入 LocalAuthentication

struct MerchantRegistrationView: View {
    @EnvironmentObject var merchantRegistryService: MerchantRegistryService
    @EnvironmentObject var blockchainService: SUIBlockchainService // 假設 SUIBlockchainService 包含錢包地址
    @Environment(\.presentationMode) var presentationMode

    @State private var merchantName: String = ""
    @State private var isLoading: Bool = false
    @State private var alertItem: AlertItem?
    @State private var showCompletionView: Bool = false
    @State private var registrationStatusMessage: String = ""
    @State private var isMerchantAlreadyRegistered: Bool = false
    @State private var existingMerchantName: String? = nil
    @State private var showRegistrationFormElements: Bool = false // 新增：控制註冊表單元素的顯示

    var body: some View {
        NavigationView {
            ZStack {
                VStack(spacing: 20) {
                    Text("商店註冊狀態") // 更新標題以反映其雙重用途
                        .font(.title2)
                        .padding(.top)

                    if isMerchantAlreadyRegistered {
                        VStack(spacing: 10) {
                            Text("您的地址已註冊商家：")
                                .font(.headline)
                            Text(existingMerchantName ?? "未知名稱")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                            Text("如需更改註冊資訊，請聯繫客服。")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                        .padding(.horizontal)
                    } else { // 尚未註冊商家
                        if showRegistrationFormElements {
                            // 顯示註冊表單元素
                            TextField("輸入商店名稱", text: $merchantName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.horizontal)
                                .disabled(isLoading || showCompletionView)

                            if isLoading && !showCompletionView {
                                ProgressView("處理中...")
                            } else if !showCompletionView {
                                Button("註冊商店") { // 最終的註冊按鈕
                                    Task {
                                        await registerMerchant()
                                    }
                                }
                                .padding()
                                .buttonStyle(.borderedProminent)
                                .disabled(merchantName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                            }
                        } else {
                            // 顯示"前往註冊"按鈕
                            Button("前往註冊商家") {
                                self.showRegistrationFormElements = true
                            }
                            .padding()
                            .buttonStyle(.borderedProminent)
                            .disabled(isLoading || showCompletionView)
                        }
                    }
                    
                    Spacer()
                }
                .navigationTitle("商店註冊")
                .navigationBarItems(leading: Button("取消") {
                    presentationMode.wrappedValue.dismiss()
                })
                .alert(item: $alertItem) { item in
                    Alert(title: Text(item.title), message: Text(item.message), dismissButton: .default(Text("好的")))
                }
                .onAppear {
                    // Call check whenever the view appears
                    checkIfMerchantIsRegistered()
                }
                // Add onChange to react to walletAddress changes specifically
                .onChange(of: blockchainService.walletAddress) { _ in
                    checkIfMerchantIsRegistered()
                }
                .onChange(of: blockchainService.isUserLoggedIn) { isLoggedIn in
                    if !isLoggedIn {
                        // If user logs out, explicitly reset state to a clean slate
                        self.isMerchantAlreadyRegistered = false
                        self.existingMerchantName = nil
                        self.showRegistrationFormElements = false
                        self.merchantName = "" // Clear any typed merchant name
                        self.isLoading = false // Reset loading state
                        self.showCompletionView = false // Hide completion view
                        self.alertItem = nil // Clear any alerts
                    } else {
                        // If user logs in or state changes while logged in, re-check registration status
                        checkIfMerchantIsRegistered()
                    }
                }

                // 完成畫面 (與之前相同)
                if showCompletionView {
                    VStack(spacing: 20) {
                        Image(systemName: "checkmark.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
                            .foregroundColor(.green)
                        
                        Text(registrationStatusMessage)
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button("完成") {
                            self.showCompletionView = false
                            self.isLoading = false
                            presentationMode.wrappedValue.dismiss()
                        }
                        .padding()
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(UIColor.systemBackground).opacity(0.95)) // 維持完成畫面的半透明背景
                    .edgesIgnoringSafeArea(.all)
                    .transition(.opacity.animation(.easeInOut))
                }
            }
            .whiteBackground() // 套用白色背景
        }
        .whiteBackground() // 也對 NavigationView 套用，確保一致性
    }

    private func checkIfMerchantIsRegistered() {
        // Only check if the user is logged in and the wallet address is valid
        guard blockchainService.isUserLoggedIn, !blockchainService.walletAddress.isEmpty else {
            self.isMerchantAlreadyRegistered = false
            self.existingMerchantName = nil
            self.showRegistrationFormElements = false // Ensure form is hidden if not logged in
            self.merchantName = "" // Clear any potentially typed merchant name
            return
        }
        let currentAddress = blockchainService.walletAddress
        if let registeredName = merchantRegistryService.getMerchantName(for: currentAddress) {
            self.existingMerchantName = registeredName
            self.isMerchantAlreadyRegistered = true
            self.showRegistrationFormElements = false // Already registered, don't show form elements directly
        } else {
            self.isMerchantAlreadyRegistered = false
            self.existingMerchantName = nil
            self.showRegistrationFormElements = false // Not registered, default to showing "Go to Register" button
        }
    }

    private func registerMerchant() async {
        isLoading = true
        hideKeyboard() // 隱藏鍵盤

        let context = LAContext()
        var error: NSError?
        let reason = "請使用 Face ID 驗證以完成商家註冊"

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            do {
                let success = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
                if success {
                    // Face ID 成功，繼續註冊流程
                    await performRegistration()
                } else {
                    // 使用者取消 Face ID 或其他原因導致 evaluatePolicy 回傳 false 但沒有 error
                    DispatchQueue.main.async {
                        self.alertItem = AlertItem(title: "認證取消", message: "Face ID 認證已取消。")
                        self.isLoading = false
                    }
                }
            } catch let authenticationError {
                // Face ID 失敗
                DispatchQueue.main.async {
                    self.alertItem = AlertItem(title: "認證失敗", message: authenticationError.localizedDescription)
                    self.isLoading = false
                }
            }
        } else {
            // 生物辨識不可用或未設定
            // 根據需求，這裡可以選擇提示使用者或直接進行註冊（如果業務邏輯允許）
            // 目前的實作是，如果無法使用生物辨識，則提示錯誤
            let authError = error?.localizedDescription ?? "您的設備不支援或未設定生物辨識。"
            // 如果是模擬器，且錯誤訊息包含 "Biometry is not available on this device."，則允許繼續進行註冊 (用於測試)
            if authError.contains("not available on this device") || authError.contains("No identities are enrolled") {
                 print("生物辨識在模擬器上不可用或未設定，將跳過 Face ID 檢查並繼續註冊。")
                 await performRegistration()
            } else {
                DispatchQueue.main.async {
                    self.alertItem = AlertItem(title: "認證錯誤", message: authError)
                    self.isLoading = false
                }
            }
        }
    }

    private func performRegistration() async {
        // 確保在主線程更新UI相關的isLoading狀態
        DispatchQueue.main.async {
            self.isLoading = true // 再次確保 isLoading 為 true
        }

        guard blockchainService.isUserLoggedIn else {
            DispatchQueue.main.async {
                self.alertItem = AlertItem(title: "錯誤", message: MerchantRegistrationError.notLoggedIn.localizedDescription ?? "請先登入")
                self.isLoading = false
            }
            return
        }

        let walletAddress = blockchainService.walletAddress
        guard !walletAddress.isEmpty else {
            DispatchQueue.main.async {
                self.alertItem = AlertItem(title: "錯誤", message: "無法獲取有效的錢包地址。請重新登入或檢查您的帳戶。")
                self.isLoading = false
            }
            return
        }
        
        let nameToRegister = merchantName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !nameToRegister.isEmpty else {
            DispatchQueue.main.async {
                self.alertItem = AlertItem(title: "錯誤", message: MerchantRegistrationError.nameIsEmpty.localizedDescription ?? "商家名稱不可為空")
                self.isLoading = false
            }
            return
        }

        // 模擬合約互動延遲
        try? await Task.sleep(nanoseconds: 1 * 1_000_000_000) // 1 秒延遲

        do {
            try merchantRegistryService.register(merchantName: nameToRegister, for: walletAddress)
            // 註冊成功，準備顯示完成畫面
            DispatchQueue.main.async {
                self.registrationStatusMessage = "商家 \\\"\\(nameToRegister)\\\" 已成功註冊！\\n此操作將模擬在鏈上進行。"
                self.showCompletionView = true
                // isLoading 會在完成畫面的按鈕中設為 false
            }
        } catch let error as MerchantRegistrationError {
            DispatchQueue.main.async {
                self.alertItem = AlertItem(title: "註冊失敗", message: error.localizedDescription ?? "發生未知錯誤")
                self.isLoading = false
            }
        } catch {
            DispatchQueue.main.async {
                self.alertItem = AlertItem(title: "註冊失敗", message: "發生未知錯誤: \\(error.localizedDescription)")
                self.isLoading = false
            }
        }
        // 注意：isLoading 的最終狀態由完成畫面的關閉按鈕或錯誤處理流程控制
    }
}
