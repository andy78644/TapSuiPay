//
//  pay_nfcApp.swift
//  pay_nfc
//
//  Created by 林信閔 on 2025/4/18.
//

import SwiftUI
import UIKit

@main
struct pay_nfcApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var serviceContainer = ServiceContainer()
    @StateObject private var appConfig = AppConfig.shared // 假設您有 AppConfig
    
    init() {
        // 初始化 ServiceContainer，確保在應用啟動時就準備好所有服務
        // 這是一個簡單的訪問就會初始化的單例
        let _ = ServiceContainer.shared
        print("已在應用啟動時初始化服務容器")
        
        // Apply all global styles at app startup
        AppStyle.applyGlobalStyles()
        
        // Force light mode for the entire app
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
            // This silences the warning with the @available attribute
            setLightModeForOlderVersions()
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                // Multiple background layers to ensure white background
                Color.white.edgesIgnoringSafeArea(.all)
                Rectangle().fill(Color.white).edgesIgnoringSafeArea(.all)
                
                ContentView()
                    .preferredColorScheme(.light) // Force light mode
                    .background(Color.white) // Ensure white background
                    .whiteBackground() // Apply our custom modifier
                    .environmentObject(serviceContainer.nfcService)
                    .environmentObject(serviceContainer.blockchainService)
                    .environmentObject(serviceContainer.zkLoginService)
                    .environmentObject(serviceContainer.merchantRegistryService) // 注入新服務
                    .environmentObject(appConfig)
                    .onOpenURL { url in
                    // Handle URL callbacks for OAuth
                    print("App received URL: \(url)")
                    NotificationCenter.default.post(
                        name: Notification.Name("HandleURLCallback"),
                        object: nil,
                        userInfo: ["url": url]
                    )
                }
            }
        }
    }
    
    // Helper method to set light mode for iOS 13-14
    @available(iOS 13.0, *)
    private func setLightModeForOlderVersions() {
        // Silence the deprecation warning by using this method
        UIApplication.shared.windows.forEach { window in
            window.overrideUserInterfaceStyle = .light
        }
    }
}
