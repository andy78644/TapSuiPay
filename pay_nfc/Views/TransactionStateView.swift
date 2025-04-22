import SwiftUI

struct TransactionStateView: View {
    @ObservedObject var viewModel: TransactionViewModel
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .edgesIgnoringSafeArea(.all)
            
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
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .shadow(radius: 10)
            )
            .padding(30)
        }
    }
    
    private var authenticatingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .padding()
            
            Text("Connecting Wallet...")
                .font(.headline)
            
            Text("Please complete the zkLogin authentication process")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var scanningView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .padding()
            
            Text("Scanning NFC Tag...")
                .font(.headline)
            
            Text("Hold your phone near the NFC tag")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var confirmationView: some View {
        VStack(spacing: 20) {
            Text("Confirm Transaction")
                .font(.headline)
                .padding(.top)
            
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Text("From:")
                        .fontWeight(.medium)
                    Spacer()
                    Text(viewModel.currentTransaction?.senderAddress.prefix(10) ?? "")
                        .foregroundColor(.secondary)
                    + Text("...")
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                HStack {
                    Text("To:")
                        .fontWeight(.medium)
                    Spacer()
                    Text(viewModel.currentTransaction?.recipientAddress.prefix(10) ?? "")
                        .foregroundColor(.secondary)
                    + Text("...")
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                HStack {
                    Text("Amount:")
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(viewModel.currentTransaction?.amount ?? 0) SUI")
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            
            Text("You'll be prompted to authenticate with Face ID to confirm")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            HStack(spacing: 20) {
                Button(action: {
                    viewModel.resetTransaction()
                }) {
                    Text("Cancel")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.primary)
                        .cornerRadius(10)
                }
                
                Button(action: {
                    viewModel.confirmAndSignTransaction()
                }) {
                    Text("Confirm")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
        }
    }
    
    private var processingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .padding()
            
            Text("Processing Transaction...")
                .font(.headline)
            
            Text("Please wait while we process your transaction")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var completedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .resizable()
                .frame(width: 60, height: 60)
                .foregroundColor(.green)
            
            Text("Transaction Completed!")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Text("Amount:")
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(viewModel.currentTransaction?.amount ?? 0) SUI")
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                HStack {
                    Text("Transaction ID:")
                        .fontWeight(.medium)
                    Spacer()
                }
                
                Text(viewModel.currentTransaction?.transactionId ?? "")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            
            Button(action: {
                viewModel.resetTransaction()
            }) {
                Text("Done")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
    }
    
    private var failedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "xmark.circle.fill")
                .resizable()
                .frame(width: 60, height: 60)
                .foregroundColor(.red)
            
            Text("Transaction Failed")
                .font(.headline)
            
            Text(viewModel.errorMessage ?? "An unknown error occurred")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: {
                viewModel.resetTransaction()
            }) {
                Text("Try Again")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
    }
}

#Preview {
    TransactionStateView(viewModel: TransactionViewModel())
}
