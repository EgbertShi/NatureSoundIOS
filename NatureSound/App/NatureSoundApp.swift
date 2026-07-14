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

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        AppDelegate.orientationLock
    }
}

@main
struct NatureSoundApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false

    init() { AudioSessionConfig.configure() }

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
