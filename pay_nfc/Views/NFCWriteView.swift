import SwiftUI

struct NFCWriteView: View {
    @State private var recipient: String = ""
    @State private var amount: String = ""
    @ObservedObject var nfcService: NFCService
    @State private var showAlert = false
    
    var body: some View {
        VStack(spacing: 24) {
            Text("NFC Tag Writer")
                .font(.title)
                .fontWeight(.bold)
                .padding(.top, 32)
            
            TextField("Recipient Address", text: $recipient)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .disableAutocorrection(true)
            
            TextField("Amount", text: $amount)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.decimalPad)
            
            Button(action: {
                hideKeyboard()
                nfcService.startWriting(recipient: recipient, amount: amount)
                showAlert = true
            }) {
                HStack {
                    Image(systemName: "wave.3.right")
                    Text("Write to NFC Tag")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
                .shadow(radius: 3)
            }
            .disabled(recipient.isEmpty || amount.isEmpty || nfcService.isScanning)
            .padding(.top, 8)
            
            if let msg = nfcService.nfcMessage {
                Text(msg)
                    .foregroundColor(msg.contains("success") ? .green : .red)
                    .multilineTextAlignment(.center)
                    .padding(.top, 16)
            }
            Spacer()
        }
        .padding()
        .alert(isPresented: $showAlert) {
            Alert(title: Text("NFC Tag"), message: Text(nfcService.nfcMessage ?? ""), dismissButton: .default(Text("OK")))
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
