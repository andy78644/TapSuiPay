import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct MainView: View {
    @StateObject private var viewModel = TransactionViewModel()
    @State private var copied = false
    @State private var showAddressCopiedToast = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 30) {
                    // Logo and Header
                    VStack(spacing: 10) {
                        Image(systemName: "wave.3.right.circle.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 100, height: 100)
                            .foregroundColor(.blue)
                        
                        Text("SUI NFC Pay")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Secure payments with Face ID and NFC")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 50)
                    
                    // Wallet Status
                    walletStatusView
                    
                    Spacer()
                    
                    // Action Button (Connect Wallet or Scan NFC)
                    // Write & Scan NFC Tag Buttons
                    if viewModel.isWalletConnected {
                        VStack(spacing: 16) {
                            NavigationLink(destination: NFCWriteView(nfcService: viewModel.nfcService)) {
                                HStack {
                                    Image(systemName: "pencil.circle")
                                    Text("Write to NFC Tag")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                                .shadow(radius: 3)
                            }
                            .padding(.horizontal, 40)

                            Button(action: {
                                viewModel.startNFCScan()
                            }) {
                                HStack {
                                    Image(systemName: "wave.3.right")
                                    Text("Scan NFC Tag")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                                .shadow(radius: 3)
                            }
                            .padding(.horizontal, 40)
                        }
                    } else {
                        // Connect Wallet Button
                        Button(action: {
                            viewModel.connectWallet()
                        }) {
                            HStack {
                                Image(systemName: "person.crop.circle.badge.checkmark")
                                Text("Connect with zkLogin")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .shadow(radius: 3)
                        }
                        .padding(.horizontal, 40)
                    }
                    
                    Spacer()
                }
                .padding()
                
                // Conditional overlay based on transaction state
                if viewModel.transactionState != .idle {
                    TransactionStateView(viewModel: viewModel)
                        .transition(.opacity)
                        .animation(.easeInOut, value: viewModel.transactionState)
                }
            }
            .navigationBarHidden(true)
            .alert(item: Binding<AlertItem?>(
                get: { viewModel.errorMessage != nil ? AlertItem(message: viewModel.errorMessage!) : nil },
                set: { _ in viewModel.errorMessage = nil }
            )) { alertItem in
                Alert(
                    title: Text("Error"),
                    message: Text(alertItem.message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    // Wallet Status View
    private var walletStatusView: some View {
        VStack(spacing: 8) {
            if viewModel.isWalletConnected {
                // 已連接頭部
                walletConnectedHeader
                
                // 地址顯示和複製按鈕 - 重寫為明確的按鈕
                let address = viewModel.getWalletAddress()
                if !address.isEmpty {
                    VStack(spacing: 5) {
                        // 地址顯示區域和明確的複製按鈕
                        HStack(spacing: 4) {
                            // 地址文字
                            HStack {
                                Text(address.prefix(6) + "..." + address.suffix(4))
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.blue.opacity(0.1))
                            )
                            
                            // 專用的複製按鈕
                            Button(action: {
                                print("複製按鈕被點擊")
                                copyToClipboard(text: address)
                            }) {
                                Image(systemName: "doc.on.doc.circle.fill")
                                    .resizable()
                                    .frame(width: 30, height: 30)
                                    .foregroundColor(.blue)
                                    .background(Color.white)
                                    .clipShape(Circle())
                                    .shadow(color: .gray.opacity(0.5), radius: 2, x: 0, y: 1)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                        }
                        
                        // 複製成功的提示
                        if copied {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("地址已複製!")
                                    .font(.caption)
                                    .foregroundColor(.green)
                                    .bold()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color.green.opacity(0.2))
                            )
                            .transition(.opacity)
                        }
                        
                        Text("點擊複製按鈕可複製錢包地址")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 2)
                    }
                }
            } else {
                // 未連接顯示
                walletNotConnectedView
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
    
    // 簡化的複製到剪貼簿功能
    private func copyToClipboard(text: String) {
        print("開始執行複製操作: \(text)")
        
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        print("iOS 複製完成")
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        print("macOS 複製完成")
        #endif
        
        withAnimation {
            copied = true
        }
        
        // 延遲1.5秒後隱藏提示
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                copied = false
            }
        }
    }
    
    // 已連接的錢包頭部視圖
    private var walletConnectedHeader: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text("Wallet Connected")
                .font(.headline)
                .foregroundColor(.green)
            
            Spacer()
            
            // 登出按鈕
            Button(action: {
                viewModel.signOut()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.caption)
                    Text("登出")
                        .font(.caption)
                }
                .foregroundColor(.red)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
    
    // 未連接錢包的顯示
    private var walletNotConnectedView: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.orange)
                Text("Wallet Not Connected")
                    .font(.headline)
                    .foregroundColor(.orange)
            }
            
            Text("Connect with zkLogin to continue")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// AlertItem moved to separate file

#Preview {
    MainView()
}
