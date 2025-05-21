import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct MainView: View {
    @StateObject private var viewModel: TransactionViewModel
    @State private var copied = false
    @State private var showAddressCopiedToast = false
    
    // Access GoogleAuthService from ServiceContainer
    @ObservedObject private var googleAuthService = ServiceContainer.shared.googleAuthService
    
    // Define unified color theme
    private let primaryColor = Color(red: 0.2, green: 0.5, blue: 0.9)
    private let secondaryColor = Color(red: 0.9, green: 0.5, blue: 0.2)
    private let backgroundColor = Color(red: 0.98, green: 0.98, blue: 1.0)
    private let cardBackgroundColor = Color.white
    
    // Use init() to initialize viewModel, ensuring we use services provided by ServiceContainer
    init() {
        // Use _StateObject wrapper to initialize @StateObject property
        _viewModel = StateObject(wrappedValue: ServiceContainer.shared.createTransactionViewModel())
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 30) {
                    // Logo and Header
                    VStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(primaryColor.opacity(0.1))
                                .frame(width: 100, height: 100)
                            
                            Image("ZyraLogo")
                                .resizable()
                                .scaledToFill()
                                .frame(width: 90, height: 90)
                                .clipShape(Circle())
                                .shadow(color: primaryColor.opacity(0.3), radius: 3, x: 0, y: 2)
                        }
                        .padding(.bottom, 10)
                        
                        Text("Zyra")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("SUI NFC Pay")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 50)
                    
                    // Google account status
                    googleAccountStatus
                    
                    // Wallet Status
                    walletStatusView
                    
                    Spacer()
                    
                    // Action Button (Connect Wallet or Scan NFC)
                    // Write & Scan NFC Tag Buttons
                    if viewModel.isWalletConnected {
                        VStack(spacing: 16) {
                            NavigationLink(destination: NFCWriteView(nfcService: viewModel.nfcService, userAddress: viewModel.getWalletAddress())) {
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
                                Image(systemName: "wallet.pass.fill")
                                Text("Connect Wallet")
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
    
    // Google account status view
    private var googleAccountStatus: some View {
        NavigationLink(destination: GoogleSignInView(googleAuthService: googleAuthService)) {
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
                        Text("Google account")
                            .font(.footnote)
                            .foregroundColor(.primary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(10)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)
            .padding(.horizontal, 20)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // Wallet Status View
    private var walletStatusView: some View {
        VStack(spacing: 8) {
            if viewModel.isWalletConnected {
                // Connected wallet header
                walletConnectedHeader
                
                // Address display and copy button
                let address = viewModel.getWalletAddress()
                if !address.isEmpty {
                    VStack(spacing: 5) {
                        // Address display area and copy button
                        HStack(spacing: 4) {
                            // Address text
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
                            
                            // Copy button
                            Button(action: {
                                print("Copy button clicked")
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
                        
                        // Copy success indicator
                        if copied {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Address copied!")
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
                        
                        Text("Click the copy button to copy wallet address")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 2)
                    }
                }
            } else {
                // Not connected display
                walletNotConnectedView
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
    
    // Simplified copy to clipboard function
    private func copyToClipboard(text: String) {
        print("Starting copy operation: \(text)")
        
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        print("iOS copy completed")
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        print("macOS copy completed")
        #endif
        
        withAnimation {
            copied = true
        }
        
        // Hide the indicator after 1.5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                copied = false
            }
        }
    }
    
    // Connected wallet header view
    private var walletConnectedHeader: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text("Wallet Connected")
                .font(.headline)
                .foregroundColor(.green)
            
            Spacer()
            
            // Logout button
            Button(action: {
                viewModel.signOut()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.caption)
                    Text("Sign Out")
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
    
    // Not connected wallet display
    private var walletNotConnectedView: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.orange)
                Text("Wallet Not Connected")
                    .font(.headline)
                    .foregroundColor(.orange)
            }
            
            Text("Connect your wallet with Face ID to continue")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// AlertItem moved to separate file

#Preview {
    MainView()
}
