import SwiftUI

struct NFCWriteView: View {
    @State private var recipient: String = ""
    @State private var amount: String = ""
    @ObservedObject var nfcService: NFCService
    @State private var showAlert = false
    @Environment(\.dismiss) private var dismiss
    
    // 定義統一的顏色主題
    private let primaryColor = Color(red: 0.2, green: 0.5, blue: 0.9)
    private let secondaryColor = Color(red: 0.9, green: 0.5, blue: 0.2)
    private let backgroundColor = Color(red: 0.98, green: 0.98, blue: 1.0)
    private let successColor = Color(red: 0.2, green: 0.8, blue: 0.4)
    private let errorColor = Color(red: 0.9, green: 0.3, blue: 0.3)
    
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
                        .font(.system(size: 40))
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
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "dollarsign.circle")
                                .foregroundColor(primaryColor)
                            Text("付款金額")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color.black.opacity(0.7))
                        }
                        
                        HStack {
                            TextField("金額", text: $amount)
                                .font(.system(size: 16))
                                .keyboardType(.decimalPad)
                            
                            Text("SUI")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(primaryColor)
                                .padding(.trailing, 8)
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
                    nfcService.startWriting(recipient: recipient, amount: amount)
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
                    HStack {
                        Image(systemName: msg.contains("success") ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .foregroundColor(msg.contains("success") ? successColor : errorColor)
                        
                        Text(msg)
                            .font(.system(size: 15))
                            .foregroundColor(msg.contains("success") ? successColor : errorColor)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(msg.contains("success") ? successColor.opacity(0.1) : errorColor.opacity(0.1))
                    )
                    .padding(.top, 16)
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
            // Only show alert if there is a message, and the session is not scanning
            if newValue != nil && !nfcService.isScanning {
                showAlert = true
            }
        }
    }
}

#if canImport(UIKit)
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
#endif
