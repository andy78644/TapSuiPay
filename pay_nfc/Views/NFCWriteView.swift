import SwiftUI

struct NFCWriteView: View {
    @State private var recipient: String = ""
    @State private var amount: String = ""
    @State private var selectedCoinType: CoinType = .SUI
    @ObservedObject var nfcService: NFCService
    @State private var showAlert = false
    @State private var writeSuccess = false
    @State private var showSuccessPopup = false
    @State private var showCopiedToast = false
    @Environment(\.dismiss) private var dismiss
    
    // 幣種類型枚舉
    enum CoinType: String, CaseIterable, Identifiable {
        case SUI = "SUI"
        case USDC = "USDC"
        
        var id: String { self.rawValue }
        
        var color: Color {
            switch self {
            case .SUI:
                return Color(red: 0.2, green: 0.5, blue: 0.9)
            case .USDC:
                return Color(red: 0.2, green: 0.6, blue: 0.4)
            }
        }
        
        var icon: String {
            switch self {
            case .SUI:
                return "dollarsign.circle"
            case .USDC:
                return "u.circle"
            }
        }
    }
    
    // 定義統一的顏色主題
    private let primaryColor = Color(red: 0.2, green: 0.5, blue: 0.9)
    private let secondaryColor = Color(red: 0.9, green: 0.5, blue: 0.2)
    private let backgroundColor = Color(red: 0.98, green: 0.98, blue: 1.0)
    private let successColor = Color(red: 0.2, green: 0.8, blue: 0.4)
    private let errorColor = Color(red: 0.9, green: 0.3, blue: 0.3)
    
    // 初始化方法，接受用戶地址作為參數，並確保地址不為空
    init(nfcService: NFCService, userAddress: String = "") {
        self.nfcService = nfcService
        // 如果提供的地址為空，則使用預設地址
        self._recipient = State(initialValue: userAddress.isEmpty ? "" : userAddress)
    }
    
    var body: some View {
        ZStack {
            // 背景
            LinearGradient(
                gradient: Gradient(colors: [backgroundColor, Color.white]),
                startPoint: .top,
                endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 24) {
                // 標題
                VStack(spacing: 10) {
                    Image(systemName: "tag.fill")
                        .foregroundColor(secondaryColor)
                    
                    Text("寫入 NFC 標籤")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(Color.black.opacity(0.8))
                    
                    Text("設定要寫入 NFC 標籤的交易資訊")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.black.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                .padding(.bottom, 10)
                
                // 表單
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "person.crop.circle")
                                .foregroundColor(primaryColor)
                            Text("收款地址")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color.black.opacity(0.7))
                        }
                        
                        TextField("收款錢包地址", text: $recipient)
                            .font(.system(size: 16))
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white)
                                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                            )
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    
                    // 幣種選擇器
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "coloncurrencysign.circle")
                                .foregroundColor(primaryColor)
                            Text("幣種")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color.black.opacity(0.7))
                        }
                        
                        HStack(spacing: 15) {
                            // SUI 按鈕
                            Button(action: {
                                selectedCoinType = .SUI
                            }) {
                                HStack {
                                    Image(systemName: CoinType.SUI.icon)
                                        .font(.system(size: 18))
                                    Text(CoinType.SUI.rawValue)
                                        .font(.system(size: 16, weight: .medium))
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 20)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(selectedCoinType == .SUI ? 
                                              CoinType.SUI.color.opacity(0.15) : 
                                              Color.gray.opacity(0.1))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(selectedCoinType == .SUI ? 
                                                        CoinType.SUI.color : 
                                                        Color.gray.opacity(0.3), lineWidth: 1.5)
                                        )
                                )
                                .foregroundColor(selectedCoinType == .SUI ? 
                                                CoinType.SUI.color : 
                                                Color.black.opacity(0.6))
                            }
                            
                            // USDC 按鈕
                            Button(action: {
                                selectedCoinType = .USDC
                            }) {
                                HStack {
                                    Image(systemName: CoinType.USDC.icon)
                                        .font(.system(size: 18))
                                    Text(CoinType.USDC.rawValue)
                                        .font(.system(size: 16, weight: .medium))
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 20)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(selectedCoinType == .USDC ? 
                                              CoinType.USDC.color.opacity(0.15) : 
                                              Color.gray.opacity(0.1))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(selectedCoinType == .USDC ? 
                                                        CoinType.USDC.color : 
                                                        Color.gray.opacity(0.3), lineWidth: 1.5)
                                        )
                                )
                                .foregroundColor(selectedCoinType == .USDC ? 
                                                CoinType.USDC.color : 
                                                Color.black.opacity(0.6))
                            }
                        }
                        .padding(.horizontal, 5)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: selectedCoinType.icon)
                                .foregroundColor(selectedCoinType.color)
                            Text("付款金額")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color.black.opacity(0.7))
                        }
                        
                        HStack {
                            TextField("金額", text: $amount)
                                .keyboardType(.decimalPad)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(selectedCoinType.color)
                                .padding(.trailing, 8)
                            
                            Text(selectedCoinType.rawValue)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(selectedCoinType.color)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white)
                                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                        )
                    }
                }
                .padding(.horizontal, 5)
                
                // 操作說明
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(primaryColor.opacity(0.7))
                        .font(.system(size: 14))
                    
                    Text("寫入 NFC 標籤後，可以用 NFC 掃描功能讀取")
                        .font(.system(size: 14))
                        .foregroundColor(Color.black.opacity(0.6))
                }
                .padding(.vertical, 5)
                
                // 確認按鈕
                Button(action: {
                    hideKeyboard()
                    nfcService.startWriting(
                        recipient: recipient,
                        amount: amount,
                        coinType: selectedCoinType.rawValue
                    )
                }) {
                    HStack {
                        Image(systemName: "wave.3.right")
                            .font(.system(size: 18))
                        
                        Text("寫入 NFC 標籤")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [secondaryColor, secondaryColor.opacity(0.8)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(16)
                    .shadow(color: secondaryColor.opacity(0.3), radius: 5, x: 0, y: 3)
                }
                .disabled(recipient.isEmpty || amount.isEmpty || nfcService.isScanning)
                .opacity(recipient.isEmpty || amount.isEmpty || nfcService.isScanning ? 0.6 : 1)
                .padding(.top, 10)
                
                // 取消按鈕
                Button(action: {
                    dismiss()
                }) {
                    Text("取消")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.black.opacity(0.6))
                        .padding(.vertical, 12)
                }
                .padding(.top, 5)
                
                // 提示訊息
                if let msg = nfcService.nfcMessage {
                    if msg.contains("success") {
                        writeSuccessView
                    } else {
                        HStack {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(errorColor)
                            
                            Text(msg)
                                .font(.system(size: 15))
                                .foregroundColor(errorColor)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(errorColor.opacity(0.1))
                        )
                        .padding(.top, 16)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 25)
            .padding(.vertical, 10)
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text(nfcService.nfcMessage?.contains("success") == true ? "成功" : "提示"),
                message: Text(nfcService.nfcMessage ?? ""),
                dismissButton: .default(Text("確定"))
            )
        }
        .onChange(of: nfcService.nfcMessage) { newValue in
            // 檢查是否有訊息且不是在掃描中
            if newValue != nil && !nfcService.isScanning {
                if newValue!.contains("success") {
                    // 成功寫入 NFC，顯示成功彈窗
                    writeSuccess = true
                    showSuccessPopup = true
                } else {
                    // 其他訊息仍使用警告框
                    showAlert = true
                }
            }
        }
        // 添加自定義成功彈出窗口
        .overlay(
            ZStack {
                if showSuccessPopup {
                    // 黑色半透明背景
                    Color.black.opacity(0.4)
                        .edgesIgnoringSafeArea(.all)
                        .onTapGesture {
                            // 點擊背景關閉彈窗
                            withAnimation(.spring()) {
                                showSuccessPopup = false
                            }
                        }
                    
                    // 成功彈窗內容
                    successPopupView
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.25), value: showSuccessPopup)
        )
    }
    
    // 定義寫入成功時的視圖
    private var writeSuccessView: some View {
        VStack(alignment: .leading, spacing: 15) {
            // 成功標題
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(successColor)
                
                Text("NFC 標籤寫入成功")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(successColor)
            }
            .padding(.bottom, 8)
            
            // 寫入內容詳情卡片
            VStack(alignment: .leading, spacing: 12) {
                // 收款地址
                HStack(alignment: .top) {
                    Image(systemName: "person.crop.circle")
                        .foregroundColor(primaryColor.opacity(0.7))
                        .font(.system(size: 16))
                    
                    Text("收款地址:")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.black.opacity(0.7))
                    
                    Spacer()
                    
                    Text(recipient)
                        .font(.system(size: 16, design: .monospaced))
                        .foregroundColor(Color.black.opacity(0.6))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                
                Divider()
                    .background(Color.black.opacity(0.1))
                
                // 金額
                HStack {
                    Image(systemName: selectedCoinType.icon)
                        .foregroundColor(selectedCoinType.color.opacity(0.7))
                        .font(.system(size: 16))
                    
                    Text("金額:")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.black.opacity(0.7))
                    
                    Spacer()
                    
                    Text("\(amount) \(selectedCoinType.rawValue)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(selectedCoinType.color)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 3)
            )
            
            // 操作提示
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(primaryColor.opacity(0.7))
                    .font(.system(size: 14))
                
                Text("該標籤已可以使用 SUI NFC Pay 應用進行掃描支付")
                    .font(.system(size: 14))
                    .foregroundColor(Color.black.opacity(0.6))
            }
            .padding(.top, 5)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(successColor.opacity(0.1))
        )
        .padding(.top, 16)
    }
    
    // 定義成功彈窗視圖
    private var successPopupView: some View {
        VStack(alignment: .center, spacing: 20) {
            // 成功標誌與動畫效果
            ZStack {
                Circle()
                    .fill(successColor.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(successColor)
            }
            
            Text("NFC 標籤寫入成功")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(successColor)
            
            // 交易詳情卡片
            transactionDetailsCard
            
            // 操作按鈕
            actionButtonsView
        }
        .padding(30)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
        .padding(.horizontal, 40)
    }
    
    // 交易詳情卡片組件
    private var transactionDetailsCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            // 收款地址
            addressInfoView
            
            Divider()
                .background(Color.black.opacity(0.1))
            
            // 金額
            amountInfoView
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 3)
        )
        .overlay(copyToastOverlay)
    }
    
    // 複製成功提示覆蓋層
    private var copyToastOverlay: some View {
        Group {
            if showCopiedToast {
                VStack {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("已複製到剪貼板")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.green.opacity(0.1))
                    )
                }
                .position(x: UIScreen.main.bounds.width/2 - 40, y: 0)
                .offset(y: -15)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
    
    // 地址信息視圖
    private var addressInfoView: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading) {
                Text("收款地址")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.black.opacity(0.5))
                
                HStack {
                    Text(recipient.prefix(15) + "..." + recipient.suffix(8))
                        .font(.system(size: 16, design: .monospaced))
                        .foregroundColor(Color.black.opacity(0.8))
                    
                    // 複製按鈕
                    Button(action: {
                        UIPasteboard.general.string = recipient
                        withAnimation {
                            showCopiedToast = true
                        }
                        // 2秒後隱藏提示
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                showCopiedToast = false
                            }
                        }
                    }) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 15))
                            .foregroundColor(primaryColor)
                    }
                }
            }
        }
    }
    
    // 金額信息視圖
    private var amountInfoView: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("金額")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.black.opacity(0.5))
                
                Text("\(amount) \(selectedCoinType.rawValue)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(selectedCoinType.color)
            }
            
            Spacer()
            
            // 幣種圖標
            Image(systemName: selectedCoinType.icon)
                .font(.system(size: 24))
                .foregroundColor(selectedCoinType.color)
        }
    }
    
    // 操作按鈕視圖
    private var actionButtonsView: some View {
        HStack(spacing: 20) {
            Button(action: {
                // 關閉彈窗並返回上一頁
                showSuccessPopup = false
                dismiss()
            }) {
                HStack {
                    Image(systemName: "checkmark")
                    Text("完成")
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .padding(.vertical, 12)
                .padding(.horizontal, 25)
                .background(successColor)
                .cornerRadius(12)
            }
            
            Button(action: {
                // 關閉彈窗並重置表單準備寫入新標籤
                showSuccessPopup = false
                // 保留收款地址，但清空金額
                amount = ""
            }) {
                HStack {
                    Image(systemName: "plus")
                    Text("再寫一個")
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(secondaryColor)
                .padding(.vertical, 12)
                .padding(.horizontal, 25)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(secondaryColor, lineWidth: 1.5)
                )
            }
        }
        .padding(.top, 10)
    }
}

#if canImport(UIKit)
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
#endif
