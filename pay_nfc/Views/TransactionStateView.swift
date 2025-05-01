import SwiftUI

struct TransactionStateView: View {
    @ObservedObject var viewModel: TransactionViewModel
    
    // 定義統一的顏色主題
    private let primaryColor = Color(red: 0.2, green: 0.5, blue: 0.9)
    private let secondaryColor = Color(red: 0.9, green: 0.5, blue: 0.2)
    private let successColor = Color(red: 0.2, green: 0.8, blue: 0.4)
    private let errorColor = Color(red: 0.9, green: 0.3, blue: 0.3)
    private let cardBackgroundColor = Color.white
    
    var body: some View {
        ZStack {
            // 半透明背景
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
            
            Text("連接錢包中...")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(Color.black.opacity(0.8))
            
            Text("請完成 zkLogin 身份驗證流程")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.black.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
    
    private var scanningView: some View {
        VStack(spacing: 25) {
            ZStack {
                // 創建波紋動畫效果
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .stroke(primaryColor.opacity(0.3 - Double(index) * 0.1), lineWidth: 3)
                        .frame(width: 60 + CGFloat(index) * 20, height: 60 + CGFloat(index) * 20)
                }
                
                Image(systemName: "wave.3.right")
                    .font(.system(size: 24))
                    .foregroundColor(primaryColor)
            }
            
            Text("掃描 NFC 標籤中...")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(Color.black.opacity(0.8))
            
            VStack(spacing: 15) {
                Text("請將手機靠近 NFC 標籤")
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
            
            Text("確認交易")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(Color.black.opacity(0.8))
            
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Image(systemName: "arrow.up.forward")
                        .font(.system(size: 16))
                        .foregroundColor(primaryColor.opacity(0.7))
                    
                    Text("從:")
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
                    
                    Text("至:")
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
                    
                    Text("金額:")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.black.opacity(0.7))
                    
                    Spacer()
                    
                    Text("\(viewModel.currentTransaction?.amount ?? 0) SUI")
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
                
                Text("您將需要使用 Face ID 進行確認")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.black.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 8)
            
            HStack(spacing: 20) {
                Button(action: {
                    viewModel.resetTransaction()
                }) {
                    Text("取消")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.1))
                        )
                        .foregroundColor(Color.black.opacity(0.7))
                }
                
                Button(action: {
                    viewModel.confirmAndSignTransaction()
                }) {
                    Text("確認")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [primaryColor, primaryColor.opacity(0.8)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .shadow(color: primaryColor.opacity(0.3), radius: 4, x: 0, y: 2)
                }
            }
        }
    }
    
    private var processingView: some View {
        VStack(spacing: 25) {
            ProgressView()
                .scaleEffect(1.5)
                .padding()
            
            Text("處理交易中...")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(Color.black.opacity(0.8))
            
            Text("請稍候，正在處理您的交易")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.black.opacity(0.6))
                .multilineTextAlignment(.center)
            
            // 處理中動畫指示器
            HStack(spacing: 20) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(primaryColor.opacity(0.7))
                        .frame(width: 10, height: 10)
                }
            }
        }
    }
    
    private var completedView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(successColor.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "checkmark.circle.fill")
                    .resizable()
                    .frame(width: 70, height: 70)
                    .foregroundColor(successColor)
                    .shadow(color: successColor.opacity(0.5), radius: 5, x: 0, y: 3)
            }
            
            Text("交易完成！")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(Color.black.opacity(0.8))
            
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Image(systemName: "dollarsign.circle")
                        .font(.system(size: 16))
                        .foregroundColor(successColor.opacity(0.8))
                    
                    Text("金額:")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.black.opacity(0.7))
                    
                    Spacer()
                    
                    Text("\(viewModel.currentTransaction?.amount ?? 0) SUI")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(successColor)
                }
                
                Divider()
                    .background(Color.black.opacity(0.1))
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "text.badge.checkmark")
                            .font(.system(size: 16))
                            .foregroundColor(successColor.opacity(0.8))
                        
                        Text("交易 ID:")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color.black.opacity(0.7))
                    }
                    
                    Text(viewModel.currentTransaction?.transactionId ?? "")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(Color.black.opacity(0.6))
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.1))
                        )
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.gray.opacity(0.05))
            )
            
            Button(action: {
                viewModel.resetTransaction()
            }) {
                Text("完成")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [successColor, successColor.opacity(0.8)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .shadow(color: successColor.opacity(0.3), radius: 4, x: 0, y: 2)
            }
        }
    }
    
    private var failedView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(errorColor.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "xmark.circle.fill")
                    .resizable()
                    .frame(width: 70, height: 70)
                    .foregroundColor(errorColor)
                    .shadow(color: errorColor.opacity(0.5), radius: 5, x: 0, y: 3)
            }
            
            Text("交易失敗")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(Color.black.opacity(0.8))
            
            Text(viewModel.errorMessage ?? "發生未知錯誤")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.black.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 10)
                .padding(.vertical, 15)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(errorColor.opacity(0.05))
                )
            
            Button(action: {
                viewModel.resetTransaction()
            }) {
                Text("重試")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
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
                    .cornerRadius(12)
                    .shadow(color: primaryColor.opacity(0.3), radius: 4, x: 0, y: 2)
            }
        }
    }
}

#Preview {
    TransactionStateView(viewModel: TransactionViewModel())
}
