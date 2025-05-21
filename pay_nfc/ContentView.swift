//
//  ContentView.swift
//  pay_nfc
//
//  Created by 林信閔 on 2025/4/18.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel: TransactionViewModel
    @State private var showNFCWrite = false
    @State private var lastReadRecipient: String? = nil
    @State private var lastReadAmount: String? = nil
    @State private var showReadInfo: Bool = false
    @State private var copied: Bool = false
    @State private var showGoogleSignIn = false
    
    // Access GoogleAuthService from ServiceContainer
    @ObservedObject private var googleAuthService = ServiceContainer.shared.googleAuthService
    
    // Define unified color theme
    private let primaryColor = Color(red: 0.2, green: 0.5, blue: 0.9)
    private let secondaryColor = Color(red: 0.9, green: 0.5, blue: 0.2)
    private let backgroundColor = Color(red: 0.98, green: 0.98, blue: 1.0)
    private let cardBackgroundColor = Color.white
    
    init() {
        // Use ServiceContainer to create view model with injected dependencies
        _viewModel = StateObject(wrappedValue: ServiceContainer.shared.createTransactionViewModel())
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Use gradient background
                LinearGradient(
                    gradient: Gradient(colors: [backgroundColor, Color.white]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 25) {
                    // Logo and title area
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(primaryColor.opacity(0.1))
                                .frame(width: 120, height: 120)
                            
                            Image("ZyraLogo")
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                                .shadow(color: primaryColor.opacity(0.5), radius: 4, x: 0, y: 2)
                        }
                        
                        Text("Zyra")
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .foregroundColor(Color(red: 0.2, green: 0.5, blue: 0.9))
                            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 1, y: 1)
                        
                        Text("SUI NFC PAY")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(Color(red: 0.3, green: 0.6, blue: 0.9))
                            .tracking(2) // Increase letter spacing
                            .padding(.top, -5)
                            .padding(.bottom, 2)
                        
                        Text("Secure payments with Face ID and NFC")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(Color.black.opacity(0.6))
                            .padding(.bottom, 5)
                    }
                    .padding(.top, 40)
                    
                    // Google account button
                    googleAccountButton
                        .padding(.horizontal, 10)
                    
                    // Wallet status view
                    walletStatusView
                        .padding(.horizontal, 10)
                    
                    Spacer()
                    
                    // Operation buttons area
                    if viewModel.isWalletConnected {
                        buttonSectionConnected
                    } else {
                        buttonSectionNotConnected
                    }
                    
                    // NFC tag info area
                    if showReadInfo {
                        nfcTagInfoView
                    }
                    
                    Spacer()
                }
                .padding()
                
                // Transaction state overlay view
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
            .sheet(isPresented: $showGoogleSignIn) {
                GoogleSignInView(googleAuthService: googleAuthService)
            }
        }
    }

    // Google account button
    private var googleAccountButton: some View {
        Button(action: {
            showGoogleSignIn = true
        }) {
            HStack {
                // Icon based on sign-in status
                Image(systemName: googleAuthService.isSignedIn ? "g.circle.fill" : "g.circle")
                    .font(.system(size: 20))
                    .foregroundColor(googleAuthService.isSignedIn ? .blue : .gray)
                
                VStack(alignment: .leading) {
                    if googleAuthService.isSignedIn {
                        Text("Signed in as")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(googleAuthService.userName)
                            .font(.footnote)
                            .foregroundColor(.primary)
                    } else {
                        Text("Sign in with Google (optional)")
                            .font(.footnote)
                            .foregroundColor(.primary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // Connect button area
    private var buttonSectionNotConnected: some View {
        VStack(spacing: 20) {
            Button(action: {
                viewModel.connectWallet()
            }) {
                HStack {
                    Image(systemName: "faceid")
                        .font(.system(size: 20))
                    
                    Text("Connect Wallet")
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
    
    // Buttons when connected
    private var buttonSectionConnected: some View {
        VStack(spacing: 20) {
            // Scan button
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
            
            // Write button
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
    
    // NFC tag info display
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
    
    // Wallet status view
    private var walletStatusView: some View {
        VStack(spacing: 15) {
            if viewModel.isWalletConnected {
                // Connected status
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 20))
                    
                    Text("Wallet Connected")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                    
                    Spacer()
                    
                    // Sign out button
                    Button(action: {
                        viewModel.signOut()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 12))
                            Text("Sign Out")
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
                
                // Wallet address display and copy
                let walletAddress = viewModel.getWalletAddress()
                if !walletAddress.isEmpty {
                    VStack(spacing: 10) {
                        HStack {
                            // Address display
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
                            
                            // Copy button
                            Button(action: {
                                copyToClipboard(walletAddress)
                            }) {
                                ZStack {
                                    // Gradient background circle
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
                                    
                                    // Glow effect - show when not copied
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
                                    
                                    // Inner glow circle - provides depth
                                    Circle()
                                        .fill(Color.white.opacity(0.15))
                                        .frame(width: 28, height: 28)
                                    
                                    // Copy icon
                                    Image(systemName: "doc.on.doc.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                                .scaleEffect(copied ? 0.95 : 1.0)
                                .animation(copied ? Animation.spring(response: 0.3, dampingFraction: 0.6) : .default, value: copied)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                        }
                        
                        // Copy success indicator
                        if copied {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.system(size: 14))
                                
                                Text("Address copied!")
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
                        
                        // Action hint
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(primaryColor.opacity(0.7))
                                .font(.system(size: 12))
                            
                            Text("Click the copy button to copy wallet address")
                                .font(.system(size: 12))
                                .foregroundColor(Color.black.opacity(0.5))
                        }
                    }
                }
                
                // Wallet type indicator
                HStack {
                    Image(systemName: "shield.lefthalf.filled")
                        .foregroundColor(primaryColor)
                        .font(.system(size: 14))
                    
                    Text("SUI Local Wallet with FaceID")
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
                // Not connected status
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "exclamationmark.shield.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 22))
                        
                        Text("Wallet Not Connected")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.orange)
                    }
                    
                    Text("Connect your wallet with Face ID to continue")
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
    
    // Copy to clipboard function
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
