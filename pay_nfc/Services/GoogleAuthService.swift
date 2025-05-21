import Foundation
import GoogleSignIn
import Combine

/// A service for managing Google authentication that doesn't affect blockchain operations
class GoogleAuthService: ObservableObject {
    @Published var isSignedIn: Bool = false
    @Published var userEmail: String = ""
    @Published var userName: String = ""
    @Published var userProfilePictureURL: URL?
    @Published var errorMessage: String?
    @Published var isAuthenticating: Bool = false
    
    private let googleClientID = "179459479770-aeoaa73k7savslnhbrru749l8jqcno6q.apps.googleusercontent.com"
    
    init() {
        // Check if user is already signed in
        checkSignInStatus()
    }
    
    /// Check if the user is already signed in with Google
    private func checkSignInStatus() {
        if let currentUser = GIDSignIn.sharedInstance.currentUser {
            updateUserInfo(user: currentUser)
            isSignedIn = true
        } else {
            isSignedIn = false
            userEmail = ""
            userName = ""
            userProfilePictureURL = nil
        }
    }
    
    /// Initiate the Google Sign-In process
    func signIn(presentingViewController: UIViewController? = nil) {
        isAuthenticating = true
        
        let configuration = GIDConfiguration(clientID: googleClientID)
        
        GIDSignIn.sharedInstance.signIn(
            with: configuration,
            presenting: presentingViewController ?? UIApplication.shared.windows.first?.rootViewController ?? UIViewController()
        ) { [weak self] user, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isAuthenticating = false
                
                if let error = error {
                    self.errorMessage = "Sign in failed: \(error.localizedDescription)"
                    return
                }
                
                guard let user = user else {
                    self.errorMessage = "No user data received"
                    return
                }
                
                self.updateUserInfo(user: user)
                self.isSignedIn = true
            }
        }
    }
    
    /// Sign out from Google account
    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        
        isSignedIn = false
        userEmail = ""
        userName = ""
        userProfilePictureURL = nil
    }
    
    /// Update user information from Google Sign-In
    private func updateUserInfo(user: GIDGoogleUser) {
        if let email = user.profile?.email {
            userEmail = email
        }
        
        if let name = user.profile?.name {
            userName = name
        }
        
        if let profilePicURL = user.profile?.imageURL(withDimension: 100) {
            userProfilePictureURL = profilePicURL
        }
    }
    
    /// Get user authentication data for analytics or preferences
    func getUserData() -> [String: Any] {
        var userData: [String: Any] = [:]
        
        if isSignedIn {
            userData["email"] = userEmail
            userData["name"] = userName
            userData["isAuthenticated"] = true
        } else {
            userData["isAuthenticated"] = false
        }
        
        return userData
    }
}
