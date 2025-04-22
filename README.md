# SUI NFC Transaction Application

An iOS application that utilizes NFC technology to enable users to read transaction information, automatically construct transactions, and sign them using Face ID before sending to the SUI blockchain.

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

## License

[Your License Information]
