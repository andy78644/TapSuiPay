import SwiftUI

struct GoogleSignInView: View {
    @ObservedObject var googleAuthService: GoogleAuthService
    @State private var showingSignInSheet = false
    @Environment(\.presentationMode) var presentationMode
    
    // Define unified color theme matching the rest of the app
    private let primaryColor = Color(red: 0.2, green: 0.5, blue: 0.9)
    private let secondaryColor = Color(red: 0.9, green: 0.5, blue: 0.2)
    private let backgroundColor = Color(red: 0.98, green: 0.98, blue: 1.0)
    private let cardBackgroundColor = Color.white
    
    var body: some View {
        VStack(spacing: 25) {
            // Header
            VStack(spacing: 10) {
                Text("Google Account")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Link your Google account for a better experience")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            // Profile section
            if googleAuthService.isSignedIn {
                VStack(spacing: 20) {
                    // Profile image
                    if let profileURL = googleAuthService.userProfilePictureURL {
                        AsyncImage(url: profileURL) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            ProgressView()
                        }
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(primaryColor, lineWidth: 3)
                        )
                        .shadow(color: Color.black.opacity(0.2), radius: 5)
                    } else {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                            .foregroundColor(primaryColor)
                    }
                    
                    // User info
                    VStack(spacing: 10) {
                        Text(googleAuthService.userName)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(googleAuthService.userEmail)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical)
                    
                    // Sign out button
                    Button(action: {
                        googleAuthService.signOut()
                    }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Sign Out")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 40)
                }
            } else {
                // Not signed in state
                VStack(spacing: 30) {
                    // Google icon
                    Image(systemName: "person.crop.circle.badge.plus")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .foregroundColor(primaryColor)
                    
                    Text("You are not signed in with Google")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    // Sign in button
                    Button(action: {
                        showingSignInSheet = true
                    }) {
                        HStack {
                            Image(systemName: "g.circle.fill")
                                .foregroundColor(.white)
                            
                            Text("Sign In with Google")
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 40)
                }
            }
            
            // Info text
            VStack(spacing: 15) {
                Text("Why link your Google account?")
                    .font(.headline)
                    .padding(.top, 30)
                
                VStack(alignment: .leading, spacing: 10) {
                    bulletPoint("Simplifies app login")
                    bulletPoint("Synchronizes preferences")
                    bulletPoint("Makes account recovery easier")
                    bulletPoint("Completely separate from wallet security")
                }
                .padding(.horizontal)
            }
            
            Spacer()
            
            // Done button
            Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Text("Done")
                    .fontWeight(.semibold)
                    .frame(width: 120)
                    .padding(.vertical, 12)
                    .background(primaryColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.bottom, 20)
        }
        .padding()
        .background(backgroundColor.edgesIgnoringSafeArea(.all))
        .onChange(of: showingSignInSheet) { newValue in
            if newValue {
                #if canImport(UIKit)
                // Get the root view controller
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootViewController = windowScene.windows.first?.rootViewController {
                    // Start Google sign-in
                    googleAuthService.signIn(presentingViewController: rootViewController)
                }
                #endif
                showingSignInSheet = false
            }
        }
        .alert(item: Binding<AlertItem?>(
            get: { googleAuthService.errorMessage != nil ? AlertItem(message: googleAuthService.errorMessage!) : nil },
            set: { _ in googleAuthService.errorMessage = nil }
        )) { alertItem in
            Alert(
                title: Text("Sign-In Error"),
                message: Text(alertItem.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    // Helper view for bullet points
    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top) {
            Text("•")
                .foregroundColor(primaryColor)
                .font(.headline)
                .padding(.trailing, 5)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
}

#Preview {
    GoogleSignInView(googleAuthService: GoogleAuthService())
}
