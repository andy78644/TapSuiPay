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
    
    var body: some View {
        NavigationView {
            ZStack {
                // Multiple layers of background color to ensure it's not black
                Color.white.edgesIgnoringSafeArea(.all)
                Rectangle().fill(Color.white).edgesIgnoringSafeArea(.all)
                
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
                    if viewModel.isWalletConnected {
                        // Scan Button
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
                        // --- NFC Write Button ---
                        Button(action: {
                            showNFCWrite = true
                        }) {
                            HStack {
                                Image(systemName: "pencil.circle")
                                Text("Write NFC Tag")
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
                        .sheet(isPresented: $showNFCWrite) {
                            NFCWriteView(nfcService: NFCService())
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
                    
                    // Show read NFC tag info if available
                    if showReadInfo {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Read NFC Tag Information:")
                                .font(.headline)
                            if let recipient = lastReadRecipient {
                                Text("Recipient: \(recipient)")
                            }
                            if let amount = lastReadAmount {
                                Text("Amount: \(amount)")
                            }
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(10)
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
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Wallet Connected")
                        .font(.headline)
                        .foregroundColor(.green)
                    
                    Spacer()
                    
                    // 添加登出按钮
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
                    .disabled(viewModel.transactionState == .authenticating)
                    .opacity(viewModel.transactionState == .authenticating ? 0.5 : 1)
                }
                
                // 获取实际的钱包地址并截取显示
                let walletAddress = viewModel.getWalletAddress()
                let shortAddress = walletAddress.isEmpty ? "0x..." : 
                    "\(walletAddress.prefix(6))...\(walletAddress.suffix(4))"
                
                Text(shortAddress)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // 添加模拟提示
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                        .font(.caption)
                    Text("SUI zkLogin Wallet")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .padding(.top, 4)
            } else {
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
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
}

// AlertItem moved to separate file

#Preview {
    ContentView()
}
