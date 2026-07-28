//
//  NatureSoundApp.swift
//  NatureSound
//
//  Created by egbert on 2026/7/1.
//

import SwiftUI
import AVFoundation
import os

// MARK: - AppDelegate 用于控制屏幕方向
class AppDelegate: NSObject, UIApplicationDelegate {
    static var orientationLock: UIInterfaceOrientationMask = .portrait

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // 尽早配置 audio session，确保后台播放权限在最早时机激活
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
            AppLogger.audio.info("应用启动时已配置音频会话: \(session.category.rawValue, privacy: .public)")
        } catch {
            AppLogger.audio.error("应用启动时音频会话配置失败: \(error.localizedDescription, privacy: .public)")
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

    @State private var audioManager = AudioManager()
    @State private var timerManager = TimerManager()
    @State private var sceneManager = SceneManager()
    @State private var weatherService = WeatherService()
    @State private var videoManager = VideoManager()

    var body: some Scene {
        WindowGroup {
            if hasSeenWelcome {
                ContentView(
                    audioManager: audioManager,
                    timerManager: timerManager,
                    sceneManager: sceneManager,
                    weatherService: weatherService,
                    videoManager: videoManager
                )
                .transition(.opacity)
            } else {
                WelcomeView(
                    audioManager: audioManager,
                    videoManager: videoManager,
                    hasSeenWelcome: $hasSeenWelcome
                )
                .transition(.opacity)
            }
        }
    }
}
