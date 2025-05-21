import SwiftUI

struct TransactionStateView: View {
    @ObservedObject var viewModel: TransactionViewModel
    
    // Define unified color theme
    private let primaryColor = Color(red: 0.2, green: 0.5, blue: 0.9)
    private let secondaryColor = Color(red: 0.9, green: 0.5, blue: 0.2)
    private let successColor = Color(red: 0.2, green: 0.8, blue: 0.4)
    private let errorColor = Color(red: 0.9, green: 0.3, blue: 0.3)
    private let cardBackgroundColor = Color.white
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.5)
                .edgesIgnoringSafeArea(.all)
                .blur(radius: 0.5)
            
            VStack(spacing: 20) {
                switch viewModel.transactionState {
                case .authenticating:
                    authenticatingView
                case .scanning:
                    scanningView
                case .confirmingTransaction:
                    confirmationView
                case .processing:
                    processingView
                case .completed:
                    completedView
                case .failed:
                    failedView
                case .idle:
                    EmptyView()
                }
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(cardBackgroundColor)
                    .shadow(color: Color.black.opacity(0.2), radius: 16, x: 0, y: 8)
            )
            .padding(30)
        }
    }
    
    private var authenticatingView: some View {
        VStack(spacing: 25) {
            ZStack {
                Circle()
                    .stroke(primaryColor.opacity(0.2), lineWidth: 6)
                    .frame(width: 80, height: 80)
                
                ProgressView()
                    .scaleEffect(1.5)
            }
            
            Text("Connecting Wallet...")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(Color.black.opacity(0.8))
            
            Text("Please complete biometric authentication to access your wallet")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.black.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
    
    private var scanningView: some View {
        VStack(spacing: 25) {
            ZStack {
                // Create ripple animation effect
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .stroke(primaryColor.opacity(0.3 - Double(index) * 0.1), lineWidth: 3)
                        .frame(width: 60 + CGFloat(index) * 20, height: 60 + CGFloat(index) * 20)
                }
                
                Image(systemName: "wave.3.right")
                    .font(.system(size: 24))
                    .foregroundColor(primaryColor)
            }
            
            Text("Scanning NFC Tag...")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(Color.black.opacity(0.8))
            
            VStack(spacing: 15) {
                Text("Please hold your phone near the NFC tag")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.black.opacity(0.6))
                    .multilineTextAlignment(.center)
                
                Image(systemName: "iphone.radiowaves.left.and.right")
                    .font(.system(size: 32))
                    .foregroundColor(primaryColor.opacity(0.7))
            }
            .padding(.horizontal)
        }
    }
    
    private var confirmationView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 32))
                .foregroundColor(primaryColor)
                .padding(.bottom, 5)
            
            Text("Confirm Transaction")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(Color.black.opacity(0.8))
            
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Image(systemName: "arrow.up.forward")
                        .font(.system(size: 16))
                        .foregroundColor(primaryColor.opacity(0.7))
                    
                    Text("From:")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.black.opacity(0.7))
                    
                    Spacer()
                    
                    Text(viewModel.currentTransaction?.senderAddress.prefix(10) ?? "")
                        .font(.system(size: 16, design: .monospaced))
                        .foregroundColor(Color.black.opacity(0.6))
                    
                    Text("...")
                        .foregroundColor(Color.black.opacity(0.6))
                }
                
                Divider()
                    .background(Color.black.opacity(0.1))
                
                HStack {
                    Image(systemName: "arrow.down.forward")
                        .font(.system(size: 16))
                        .foregroundColor(primaryColor.opacity(0.7))
                    
                    Text("To:")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.black.opacity(0.7))
                    
                    Spacer()
                    
                    Text(viewModel.currentTransaction?.recipientAddress.prefix(10) ?? "")
                        .font(.system(size: 16, design: .monospaced))
                        .foregroundColor(Color.black.opacity(0.6))
                    
                    Text("...")
                        .foregroundColor(Color.black.opacity(0.6))
                }
                
                Divider()
                    .background(Color.black.opacity(0.1))
                
                HStack {
                    Image(systemName: "dollarsign.circle")
                        .font(.system(size: 16))
                        .foregroundColor(primaryColor.opacity(0.7))
                    
                    Text("Amount:")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.black.opacity(0.7))
                    
                    Spacer()
                    
                    Text("\(viewModel.currentTransaction?.amount ?? 0) \(viewModel.currentTransaction?.coinType ?? "SUI")")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(primaryColor)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.gray.opacity(0.05))
            )
            
            HStack {
                Image(systemName: "faceid")
                    .font(.system(size: 14))
                    .foregroundColor(primaryColor)
                
                Text("You'll need to use Face ID to confirm")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.black.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 8)
            
            HStack(spacing: 20) {
                Button(action: {
                    viewModel.resetTransaction()
                }) {
                    Text("Cancel")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.gray.opacity(0.15))
                        .foregroundColor(Color.black.opacity(0.7))
                        .cornerRadius(12)
                }
                
                Button(action: {
                    viewModel.confirmAndSignTransaction()
                }) {
                    Text("Confirm")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(primaryColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
        }
    }
    
    private var processingView: some View {
        VStack(spacing: 25) {
            ZStack {
                Circle()
                    .trim(from: 0, to: 0.75)
                    .stroke(primaryColor.opacity(0.7), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(360))
                    .animation(Animation.linear(duration: 1).repeatForever(autoreverses: false), value: UUID())
                
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 24))
                    .foregroundColor(primaryColor)
            }
            
            Text("Processing Transaction...")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(Color.black.opacity(0.8))
            
            Text("Please wait while we process your transaction on the blockchain")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.black.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
    
    private var completedView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(successColor.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(successColor)
            }
            
            Text("Transaction Complete!")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(Color.black.opacity(0.8))
            
            Text("Your payment has been successfully processed")
                .font(.system(size: 16))
                .foregroundColor(Color.black.opacity(0.6))
                .multilineTextAlignment(.center)
            
            if let url = viewModel.transactionUrl {
                Link(destination: url) {
                    HStack {
                        Image(systemName: "link")
                            .font(.system(size: 14))
                        
                        Text("View on Explorer")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(primaryColor)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(primaryColor, lineWidth: 1)
                    )
                }
                .padding(.top, 5)
            }
            
            Button(action: {
                viewModel.resetTransaction()
            }) {
                Text("Done")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .frame(width: 120)
                    .padding(.vertical, 12)
                    .background(successColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .shadow(color: successColor.opacity(0.4), radius: 5, x: 0, y: 3)
            }
            .padding(.top, 10)
        }
    }
    
    private var failedView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(errorColor.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(errorColor)
            }
            
            Text("Transaction Failed")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(Color.black.opacity(0.8))
            
            Text(viewModel.errorMessage ?? "There was an error processing your transaction")
                .font(.system(size: 16))
                .foregroundColor(Color.black.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: {
                viewModel.resetTransaction()
            }) {
                Text("Close")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .frame(width: 120)
                    .padding(.vertical, 12)
                    .background(Color.gray.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.top, 10)
        }
    }
}

#Preview {
    TransactionStateView(viewModel: TransactionViewModel())
        .previewLayout(.sizeThatFits)
        .padding()
}
