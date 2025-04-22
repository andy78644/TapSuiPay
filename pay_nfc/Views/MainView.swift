import SwiftUI

struct MainView: View {
    @StateObject private var viewModel = TransactionViewModel()
    
    var body: some View {
        NavigationView {
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
                    if viewModel.isWalletConnected {
                        // Scan Button
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
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Wallet Connected")
                        .font(.headline)
                        .foregroundColor(.green)
                }
                
                Text(viewModel.isWalletConnected ? "0x123abc..." : "")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
    MainView()
}
