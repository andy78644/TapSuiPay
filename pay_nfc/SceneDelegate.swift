import UIKit
import SwiftUI
import GoogleSignIn

@available(iOS 13.0, *)
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Create the SwiftUI view that provides the window contents
        let contentView = ContentView()

        // Use a UIHostingController as window root view controller
        if let windowScene = scene as? UIWindowScene {
            let window = UIWindow(windowScene: windowScene)
            window.rootViewController = UIHostingController(rootView: contentView)
            self.window = window
            window.makeKeyAndVisible()
        }
        
        // Handle any URL that was used to launch the app
        if let urlContext = connectionOptions.urlContexts.first {
            handleIncomingURL(urlContext.url)
        }
    }
    
    // Handle URLs opened while the app is running
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        if let urlContext = URLContexts.first {
            handleIncomingURL(urlContext.url)
        }
    }
    
    // Process incoming URLs (for OAuth callbacks)
    private func handleIncomingURL(_ url: URL) {
        // 先尝试让GoogleSignIn处理
        if GIDSignIn.sharedInstance.handle(url) {
            return
        }
        
        // 如果不是GoogleSignIn URL，则通过通知处理
        NotificationCenter.default.post(
            name: Notification.Name("HandleURLCallback"),
            object: nil,
            userInfo: ["url": url]
        )
        
        print("Received URL: \(url)")
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called when the scene is being released by the system
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background
    }
}
