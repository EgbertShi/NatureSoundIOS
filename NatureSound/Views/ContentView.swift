//
//  ContentView.swift
//  NatureSound
//
//  Created by egbert on 2026/7/1.
//

import SwiftUI

struct ContentView: View {
    let audioManager: AudioManager
    let timerManager: TimerManager
    let sceneManager: SceneManager
    let weatherService: WeatherService
    let videoManager: VideoManager

    @State private var selectedTab = 0
    @State private var showStandby = false
    @State private var showSettings = false
    /// 模式设置 Sheet 展示状态
    @State private var showModeSetup = false
    /// 当前选中的模式（用于传递给 ModeSetupSheet）
    @State private var selectedMode: FocusMode = .sleep
    /// 唤醒 Overlay 展示状态
    @State private var showWakeUp = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                SoundsPage(
                    audioManager: audioManager,
                    timerManager: timerManager,
                    weatherService: weatherService,
                    videoManager: videoManager,
                    showSettings: $showSettings,
                    onSelectMode: { mode in
                        selectedMode = mode
                        showModeSetup = true
                    }
                )
                .tabItem { Label("声音", systemImage: "chart.bar.fill") }
                .tag(0)

                ScenesPage(
                    audioManager: audioManager,
                    sceneManager: sceneManager,
                    videoManager: videoManager,
                    showSettings: $showSettings
                )
                .background(Theme.backgroundGradient(colorScheme).ignoresSafeArea())
                .tabItem { Label("场景", systemImage: "square.stack.3d.up.fill") }
                .tag(1)

                MyScenesPage(
                    audioManager: audioManager,
                    sceneManager: sceneManager,
                    showSettings: $showSettings
                )
                .background(Theme.backgroundGradient(colorScheme).ignoresSafeArea())
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
                    .frame(maxWidth: sizeClass == .regular ? 520 : .infinity)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 54)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // MARK: 唤醒 Overlay
            if showWakeUp {
                WakeUpOverlay(
                    timerManager: timerManager,
                    audioManager: audioManager,
                    onContinue: {
                        withAnimation(.spring(response: 0.4)) {
                            showWakeUp = false
                        }
                        timerManager.dismissWakeUp()
                    },
                    onStop: {
                        withAnimation(.spring(response: 0.4)) {
                            showWakeUp = false
                            audioManager.stopAll()
                        }
                        showStandby = false
                        timerManager.stopFromWakeUp()
                    }
                )
                .transition(.opacity)
                .zIndex(100) // 确保在最顶层
            }
        }
        // 注意：MiniPlayerBar 的显隐动画统一由各触发点（SoundsPage.handleSoundTap、
        // applyScene/applyPreset/applyUserScene 等）通过 withAnimation 显式声明，
        // 这里不再叠加隐式的 .animation(value:)。此前双重动画声明（顶层隐式动画 +
        // 触发点显式 withAnimation 同时作用于 activeCount）在耗时的音频加载操作
        // 与动画事务提交产生时序竞态时，会偶发导致 MiniPlayerBar 该出现却未正确显示。
        .onAppear { weatherService.fetchWeatherIfNeeded() }
        .fullScreenCover(isPresented: $showStandby) {
            StandbyView(audioManager: audioManager, timerManager: timerManager, sceneManager: sceneManager, videoManager: videoManager, isPresented: $showStandby)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                // 回到前台：恢复所有播放器（AVAudioPlayer 后台本身不会停，
                // 但音频中断等场景可能导致暂停，此处做兜底恢复）
                audioManager.resumeAll()
                // 首次安装时，系统定位授权弹窗会让 App 短暂进入 inactive/background，
                // 授权结果确认后回到前台，此处兜底再次尝试获取天气，
                // 避免仅依赖授权回调这一条路径导致天气长期未刷新。
                weatherService.fetchWeatherIfNeeded()
            }
        }
        .onChange(of: audioManager.activeCount) { _, newCount in
            // 用户手动停止所有播放后，定时器也应一起停掉
            if newCount == 0 && timerManager.isActive {
                timerManager.stop()
            }
        }
        .onChange(of: timerManager.fadeOutProgress) { _, progress in
            audioManager.applyFadeOut(progress: progress)
        }
        .onChange(of: timerManager.isActive) { oldValue, newValue in
            // 定时器从活跃变为非活跃 → 定时结束
            if oldValue && !newValue {
                // 检查是否触发了唤醒（非入睡模式定时结束）
                if timerManager.wakeUpTriggered {
                    // 弹出唤醒 Overlay，保持音频播放
                    withAnimation(.spring(response: 0.4)) {
                        showWakeUp = true
                    }
                } else {
                    // 入睡模式或无模式：直接停止
                    withAnimation(.spring(response: 0.4)) {
                        audioManager.stopAll()
                    }
                    showStandby = false
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsPage(audioManager: audioManager, sceneManager: sceneManager, isPresented: $showSettings)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showModeSetup) {
            ModeSetupSheet(
                mode: selectedMode,
                audioManager: audioManager,
                timerManager: timerManager,
                videoManager: videoManager,
                isPresented: $showModeSetup,
                onStart: { scene, minutes in
                    startModePlayback(scene: scene, minutes: minutes)
                }
            )
            .presentationDetents([.medium])
        }
    }

    // MARK: - 模式播放启动

    /// 模式设置完成后：播放场景 + 启动定时器
    private func startModePlayback(scene: ScenePreset, minutes: Int) {
        // 播放场景
        withAnimation(.spring(response: 0.4)) {
            ScenePlaybackCoordinator(audioManager: audioManager, videoManager: videoManager).apply(scene)
        }

        // 启动带模式的定时器
        timerManager.start(mode: selectedMode, minutes: minutes) {
            // 入睡模式的 onComplete 回调（停止播放）
            // 需要唤醒的模式不会走到这个回调（由 handleTimerEnd 内部处理）
        }
    }
}

#Preview {
    ContentView(
        audioManager: AudioManager(),
        timerManager: TimerManager(),
        sceneManager: SceneManager(),
        weatherService: WeatherService(),
        videoManager: VideoManager()
    )
}
