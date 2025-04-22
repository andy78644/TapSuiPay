import SwiftUI
import UIKit

// Global styling for the app
struct AppStyle {
    // Apply all global styles at app startup
    static func applyGlobalStyles() {
        // Force light mode for the entire app using the recommended approach
        if #available(iOS 15.0, *) {
            // Use the recommended approach for iOS 15.0+
            for scene in UIApplication.shared.connectedScenes {
                if let windowScene = scene as? UIWindowScene {
                    for window in windowScene.windows {
                        window.overrideUserInterfaceStyle = .light
                    }
                }
            }
        } else if #available(iOS 13.0, *) {
            // Deprecated but still works for iOS 13.0-14.x
            setLightModeForOlderVersions()
        }
        
        // Set navigation bar appearance
        let navigationBarAppearance = UINavigationBarAppearance()
        navigationBarAppearance.configureWithOpaqueBackground()
        navigationBarAppearance.backgroundColor = .white
        navigationBarAppearance.titleTextAttributes = [.foregroundColor: UIColor.black]
        navigationBarAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.black]
        
        UINavigationBar.appearance().standardAppearance = navigationBarAppearance
        UINavigationBar.appearance().compactAppearance = navigationBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navigationBarAppearance
        UINavigationBar.appearance().tintColor = .systemBlue
        
        // Set tab bar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = .white
        
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        UITabBar.appearance().tintColor = .systemBlue
    }
    
    // Helper method to set light mode for iOS 13-14
    @available(iOS 13.0, *)
    static private func setLightModeForOlderVersions() {
        // Silence the deprecation warning by using this method
        UIApplication.shared.windows.forEach { window in
            window.overrideUserInterfaceStyle = .light
        }
    }
}

// Extension to add background modifier to any view
extension View {
    func whiteBackground() -> some View {
        self
            .background(Color.white)
            .preferredColorScheme(.light)
    }
}
