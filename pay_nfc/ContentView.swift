//
//  ContentView.swift
//  pay_nfc
//
//  Created by 林信閔 on 2025/4/18.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = TransactionViewModel()
    @State private var showNFCWrite = false
    @State private var lastReadRecipient: String? = nil
    @State private var lastReadAmount: String? = nil
    @State private var showReadInfo: Bool = false
    @State private var copied: Bool = false
    
    // 定義統一的顏色主題
    private let primaryColor = Color(red: 0.2, green: 0.5, blue: 0.9)
    private let secondaryColor = Color(red: 0.9, green: 0.5, blue: 0.2)
    private let backgroundColor = Color(red: 0.98, green: 0.98, blue: 1.0)
    private let cardBackgroundColor = Color.white
    
    var body: some View {
        NavigationView {
            ZStack {
                // 使用漸變背景
                LinearGradient(
                    gradient: Gradient(colors: [backgroundColor, Color.white]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 25) {
                    // Logo 和標題區
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(primaryColor.opacity(0.1))
                                .frame(width: 120, height: 120)
                            
                            Image(systemName: "wave.3.right.circle.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 80, height: 80)
                                .foregroundColor(primaryColor)
                                .shadow(color: primaryColor.opacity(0.5), radius: 4, x: 0, y: 2)
                        }
                        
                        Text("SUI NFC Pay")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(Color.black.opacity(0.8))
                        
                        Text("Secure payments with Face ID and NFC")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(Color.black.opacity(0.6))
                            .padding(.bottom, 5)
                    }
                    .padding(.top, 40)
                    
                    // 錢包狀態視圖
                    walletStatusView
                        .padding(.horizontal, 10)
                    
                    Spacer()
                    
                    // 操作按鈕區域
                    if viewModel.isWalletConnected {
                        buttonSectionConnected
                    } else {
                        buttonSectionNotConnected
                    }
                    
                    // NFC 標籤信息顯示區域
                    if showReadInfo {
                        nfcTagInfoView
                    }
                    
                    Spacer()
                }
                .padding()
                
                // 交易狀態覆蓋視圖
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
    
    // 連接按鈕區域
    private var buttonSectionNotConnected: some View {
        VStack(spacing: 20) {
            Button(action: {
                viewModel.connectWallet()
            }) {
                HStack {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .font(.system(size: 20))
                    
                    Text("Connect with zkLogin")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [primaryColor, primaryColor.opacity(0.8)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(16)
                .shadow(color: primaryColor.opacity(0.4), radius: 5, x: 0, y: 3)
            }
            .padding(.horizontal, 25)
        }
    }
    
    // 已連接時的按鈕區域
    private var buttonSectionConnected: some View {
        VStack(spacing: 20) {
            // 掃描按鈕
            Button(action: {
                viewModel.startNFCScan()
                // Listen for NFC read result with a slight delay to allow NFCService to update
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    if let data = viewModel.nfcService.transactionData {
                        lastReadRecipient = data["recipient"]
                        lastReadAmount = data["amount"]
                        showReadInfo = (lastReadRecipient != nil || lastReadAmount != nil)
                    }
                }
            }) {
                HStack {
                    Image(systemName: "wave.3.right")
                        .font(.system(size: 20))
                    
                    Text("Scan NFC Tag")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [primaryColor, primaryColor.opacity(0.8)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(16)
                .shadow(color: primaryColor.opacity(0.4), radius: 5, x: 0, y: 3)
            }
            .padding(.horizontal, 25)
            
            // 寫入按鈕
            Button(action: {
                showNFCWrite = true
            }) {
                HStack {
                    Image(systemName: "pencil.circle")
                        .font(.system(size: 20))
                    
                    Text("Write NFC Tag")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
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
                .shadow(color: secondaryColor.opacity(0.4), radius: 5, x: 0, y: 3)
            }
            .padding(.horizontal, 25)
            .sheet(isPresented: $showNFCWrite) {
                NFCWriteView(nfcService: NFCService(), userAddress: viewModel.getWalletAddress())
            }
        }
    }
    
    // NFC 標籤信息顯示
    private var nfcTagInfoView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "tag.fill")
                    .foregroundColor(primaryColor)
                
                Text("NFC Tag Information")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(Color.black.opacity(0.8))
            }
            
            if let recipient = lastReadRecipient {
                HStack(alignment: .top) {
                    Text("Recipient:")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.black.opacity(0.7))
                    
                    Text(recipient)
                        .font(.system(size: 16))
                        .foregroundColor(Color.black.opacity(0.6))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            
            if let amount = lastReadAmount {
                HStack {
                    Text("Amount:")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.black.opacity(0.7))
                    
                    Text("\(amount) SUI")
                        .font(.system(size: 16))
                        .foregroundColor(Color.black.opacity(0.6))
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 5)
        )
        .padding(.horizontal, 25)
        .padding(.top, 10)
    }
    
    // 錢包狀態視圖
    private var walletStatusView: some View {
        VStack(spacing: 15) {
            if viewModel.isWalletConnected {
                // 已連接狀態
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 20))
                    
                    Text("Wallet Connected")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                    
                    Spacer()
                    
                    // 登出按鈕
                    Button(action: {
                        viewModel.signOut()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 12))
                            Text("登出")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.red.opacity(0.1))
                        )
                        .foregroundColor(.red)
                    }
                    .disabled(viewModel.transactionState == .authenticating)
                    .opacity(viewModel.transactionState == .authenticating ? 0.5 : 1)
                }
                
                // 錢包地址顯示和複製
                let walletAddress = viewModel.getWalletAddress()
                if !walletAddress.isEmpty {
                    VStack(spacing: 10) {
                        HStack {
                            // 地址顯示
                            HStack {
                                Image(systemName: "wallet.pass.fill")
                                    .foregroundColor(primaryColor.opacity(0.7))
                                    .font(.system(size: 14))
                                
                                Text(walletAddress.prefix(6) + "..." + walletAddress.suffix(4))
                                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                                    .foregroundColor(Color.black.opacity(0.7))
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(primaryColor.opacity(0.08))
                            )
                            
                            // 複製按鈕
                            Button(action: {
                                copyToClipboard(walletAddress)
                            }) {
                                ZStack {
                                    // 漸變背景圓形
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: [primaryColor.opacity(0.9), primaryColor]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 38, height: 38)
                                        .shadow(color: primaryColor.opacity(0.3), radius: 3, x: 0, y: 2)
                                    
                                    // 閃光效果 - 當未複製時顯示
                                    if !copied {
                                        Circle()
                                            .fill(Color.white.opacity(0.1))
                                            .frame(width: 38, height: 38)
                                            .mask(
                                                LinearGradient(
                                                    gradient: Gradient(
                                                        colors: [Color.clear, Color.white.opacity(0.5), Color.clear]
                                                    ),
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                    }
                                    
                                    // 內層發光圓形 - 提供深度感
                                    Circle()
                                        .fill(Color.white.opacity(0.15))
                                        .frame(width: 28, height: 28)
                                    
                                    // 複製圖標
                                    Image(systemName: "doc.on.doc.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                                .scaleEffect(copied ? 0.95 : 1.0)
                                .animation(copied ? Animation.spring(response: 0.3, dampingFraction: 0.6) : .default, value: copied)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                        }
                        
                        // 複製成功提示
                        if copied {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.system(size: 14))
                                
                                Text("地址已複製!")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.green)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.green.opacity(0.1))
                            )
                            .transition(.scale.combined(with: .opacity))
                        }
                        
                        // 操作提示
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(primaryColor.opacity(0.7))
                                .font(.system(size: 12))
                            
                            Text("點擊複製按鈕可複製錢包地址")
                                .font(.system(size: 12))
                                .foregroundColor(Color.black.opacity(0.5))
                        }
                    }
                }
                
                // 錢包類型提示
                HStack {
                    Image(systemName: "shield.lefthalf.filled")
                        .foregroundColor(primaryColor)
                        .font(.system(size: 14))
                    
                    Text("SUI zkLogin Wallet")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(primaryColor)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(primaryColor.opacity(0.08))
                )
                .padding(.top, 4)
            } else {
                // 未連接狀態
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "exclamationmark.shield.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 22))
                        
                        Text("Wallet Not Connected")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.orange)
                    }
                    
                    Text("Connect with zkLogin to continue")
                        .font(.system(size: 16))
                        .foregroundColor(Color.black.opacity(0.5))
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(cardBackgroundColor)
                .shadow(color: Color.black.opacity(0.08), radius: 15, x: 0, y: 5)
        )
    }
    
    // 複製到剪貼板功能
    private func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
        
        withAnimation(.spring()) {
            copied = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeOut) {
                copied = false
            }
        }
    }
}

#Preview {
    ContentView()
}
