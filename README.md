
# Zyra - SUI NFC Transaction Application

Zyra is a payment app that makes sending money easy and safe using your phone. It uses NFC technology (like tapping your phone to pay) and the Sui blockchain to keep things fast and secure. Here’s how it works and why it’s useful:

## How It Works
1. **Tap to Start**: Just tap your phone on an NFC tag to begin a payment.
2. **See the Details**: The app shows you who you’re paying and how much it is.
3. **Auto-Fill**: It puts in your address for you, so you don’t have to type it.
4. **Confirm with FaceID**: Use your face to say “yes” to the payment—it’s quick and safe.
5. **Done**: The app sends the payment to the Sui blockchain, which handles it fast and keeps it secure.

## Getting Started
You’ll set up a wallet in the app using zkLogin. This wallet holds your money and keeps it safe. Every time you pay, FaceID makes sure it’s really you, so no one else can use your account.

## Why It’s Good
- **Fast**: Tap, check, confirm—payments are done in seconds.
- **Easy**: No typing your info every time—the app does it for you.
- **Safe**: FaceID and the blockchain keep your money protected.

Zyra makes paying for things or sending money simple and worry-free. It’s practical for everyday use, whether you’re shopping or splitting a bill.

---

## Features
- NFC tag reading for transaction information
- Transaction construction using SUI blockchain
- Face ID authentication for secure transaction signing
- Transaction submission to SUI blockchain
- User-friendly transaction flow with status updates

## Requirements
- iOS 11.0+
- Xcode 12.0+
- iPhone 7 or newer (NFC-capable device)
- Developer account with NFC capabilities enabled

## Setup Instructions
1. Clone the repository
2. Open the project in Xcode
3. Configure your development team in the Signing & Capabilities section
4. Enable the NFC Tag Reading capability in the Signing & Capabilities section
5. Build and run the application on a physical device (NFC is not available in the simulator)

## NFC Tag Format
The application expects NFC tags to be in NDEF format with the following data structure:
```
recipient=<recipient_address>&amount=<amount_in_sui>
```
Example:
```
recipient=0x987654321abcdef0987654321abcdef098765432&amount=10.5
```

## Project Structure
- **Models**: Data structures for transactions
- **Services**: Core functionality for NFC reading and blockchain integration
- **ViewModels**: Business logic and state management
- **Views**: User interface components

## Usage
1. Launch the application
2. Tap "Scan NFC Tag" button
3. Hold the device near an NFC tag containing transaction information
4. Review the transaction details
5. Confirm the transaction
6. Authenticate with Face ID
7. View the transaction result

## Note
This application currently uses simulated blockchain integration. In a production environment, you would need to integrate with the actual SUI blockchain SDK.

---

Zyra is designed to make blockchain payments as easy as tapping your phone. With NFC and FaceID, it’s fast, secure, and simple to use. Try it out and experience the future of payments today!
