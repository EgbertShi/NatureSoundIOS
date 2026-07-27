//
//  NatureSoundApp.swift
//  NatureSound
//
//  Created by egbert on 2026/7/1.
//

import SwiftUI
import AVFoundation

// MARK: - AppDelegate 用于控制屏幕方向
class AppDelegate: NSObject, UIApplicationDelegate {
    static var orientationLock: UIInterfaceOrientationMask = .portrait

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // 尽早配置 audio session，确保后台播放权限在最早时机激活
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
            print("[AppDelegate] ✅ audio session 配置成功: category=\(session.category.rawValue)")
        } catch {
            print("[AppDelegate] ❌ audio session 配置失败: \(error)")
        }
        return true
    }

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        AppDelegate.orientationLock
    }
}

@main
struct NatureSoundApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false

    var body: some Scene {
        WindowGroup {
            if hasSeenWelcome {
                ContentView().transition(.opacity)
            } else {
                WelcomeView(hasSeenWelcome: $hasSeenWelcome).transition(.opacity)
            }
        }
    }
}
