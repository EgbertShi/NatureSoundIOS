//
//  ContentView.swift
//  NatureSound
//
//  Created by egbert on 2026/7/1.
//

import SwiftUI

struct ContentView: View {
    @State private var audioManager = AudioManager()
    @State private var timerManager = TimerManager()
    @State private var sceneManager = SceneManager()
    @State private var weatherService = WeatherService()
    @State private var videoManager = VideoManager()
    @State private var selectedTab = 0
    @State private var showStandby = false
    @State private var showSettings = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                SoundsPage(
                    audioManager: audioManager,
                    timerManager: timerManager,
                    weatherService: weatherService,
                    showSettings: $showSettings
                )
                .tabItem { Label("声音", systemImage: "chart.bar.fill") }
                .tag(0)

                ScenesPage(
                    audioManager: audioManager,
                    sceneManager: sceneManager,
                    videoManager: videoManager,
                    showSettings: $showSettings
                )
                .background(Theme.backgroundGradient(.light).ignoresSafeArea())
                .tabItem { Label("场景", systemImage: "square.stack.3d.up.fill") }
                .tag(1)

                MyScenesPage(
                    audioManager: audioManager,
                    sceneManager: sceneManager,
                    showSettings: $showSettings
                )
                .background(Theme.backgroundGradient(.light).ignoresSafeArea())
                .tabItem { Label("我的", systemImage: "star.fill") }
                .tag(2)
            }
            .tint(Theme.accent)

            if audioManager.activeCount > 0 {
                MiniPlayerBar(audioManager: audioManager, timerManager: timerManager)
                    .onTapGesture {
                        Haptics.light()
                        showStandby = true
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 54)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4), value: audioManager.activeCount)
        .preferredColorScheme(.light)
        .onAppear { weatherService.fetchWeatherIfNeeded() }
        .fullScreenCover(isPresented: $showStandby) {
            StandbyView(audioManager: audioManager, timerManager: timerManager, sceneManager: sceneManager, videoManager: videoManager, isPresented: $showStandby)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active { audioManager.resumeAll() }
        }
        .onChange(of: timerManager.fadeOutProgress) { _, progress in
            audioManager.applyFadeOut(progress: progress)
        }
        .sheet(isPresented: $showSettings) {
            SettingsPage(audioManager: audioManager, sceneManager: sceneManager, isPresented: $showSettings)
                .presentationDetents([.medium])
        }
    }
}

#Preview {
    ContentView()
}
