import UIKit
import SwiftUI
import GoogleSignIn

class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // 配置GoogleSignIn
        GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
            if error != nil || user == nil {
                // 未登录状态，这很正常
                print("No previous Google Sign In found")
            } else {
                print("Previous Google Sign In restored")
            }
        }
        return true
    }
    
    // Handle URL schemes for older iOS versions
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        // 首先尝试处理为GoogleSignIn URL
        if GIDSignIn.sharedInstance.handle(url) {
            return true
        }
        
        // 其他URL转发到我们的通知系统
        print("AppDelegate received URL: \(url)")
        NotificationCenter.default.post(
            name: Notification.Name("HandleURLCallback"),
            object: nil,
            userInfo: ["url": url]
        )
        return true
    }
}
