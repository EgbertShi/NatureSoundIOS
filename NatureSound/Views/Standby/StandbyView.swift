//
//  StandbyView.swift
//  NatureSound
//
//  Created by egbert on 2026/7/11.
//

import SwiftUI
import UIKit
internal import Combine

// MARK: - 待机界面
struct StandbyView: View {
    let audioManager: AudioManager
    let timerManager: TimerManager
    let sceneManager: SceneManager
    let videoManager: VideoManager
    @Binding var isPresented: Bool

    @StateObject private var orientationManager = OrientationManager()
    @State private var selectedSceneID: String?
    @State private var selectedVideoVariant = 0

    // 亮度
    @State private var brightness: Double = Double(UIScreen.main.brightness)
    @State private var originalBrightness: Double = Double(UIScreen.main.brightness)

    // 音量
    @State private var masterVolume: Float = 0.8

    // UI 状态
    @State private var showControls = true
    @State private var currentTime = Date()
    @State private var waveOffset: CGFloat = 0

    // 迷你混音器
    @State private var showMixer = false

    // 保存场景
    @State private var showSaveScene = false
    @State private var sceneName = ""

    // 偏好设置
    @AppStorage("standby_use24Hour") private var use24Hour = true
    @AppStorage("standby_showSeconds") private var showSeconds = false
    @AppStorage("standby_showDate") private var showDate = true
    @AppStorage("standby_clockStyle") private var clockStyleRaw = "数字"
    @AppStorage("standby_clockScale") private var clockScale: Double = 1.0

    @State private var clockTimer: Foundation.Timer?

    private var clockStyle: ClockStyle { ClockStyle(rawValue: clockStyleRaw) ?? .digital }
    private var primaryColor: Color { audioManager.activePlayers.first?.sound.color ?? Color(hex: "667eea") }
    private var clockFormatter: ClockTimeFormatter { ClockTimeFormatter(use24Hour: use24Hour, showSeconds: showSeconds, showDate: showDate) }
    private var showTimerRing: Bool { timerManager.isActive }
    private var videoScenes: [ScenePreset] { ScenePreset.allPresets.filter { videoManager.hasAsset(for: $0.id) } }
    private var selectedScene: ScenePreset? { videoScenes.first { $0.id == selectedSceneID } }
    private var videoVariantCount: Int { selectedScene.map { videoManager.videoVariantCount(for: $0.id) } ?? 0 }

    var body: some View {
        ZStack {
            Group {
                if let selectedScene {
                    ImmersiveVideoBackground(
                        scene: selectedScene,
                        variantIndex: selectedVideoVariant,
                        variantCount: videoVariantCount,
                        videoManager: videoManager
                    )
                    .id(selectedScene.id)
                } else {
                    StandbyBackground(
                        primaryColor: primaryColor,
                        activePlayers: audioManager.activePlayers
                    )
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { if !showControls { toggleControls() } }

            // 控制面板显示时，铺满全屏的捕获层：点击面板外区域关闭面板
            if showControls {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { dismissControls() }
            }

            immersiveLayout
                .zIndex(1)

            VStack {
                Spacer()
                VideoPageIndicator(count: videoVariantCount, current: selectedVideoVariant)
                    .padding(.bottom, 36)
            }
            .allowsHitTesting(false)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height), abs(value.translation.width) > 50 else { return }
                    switchVideoVariant(forward: value.translation.width < 0)
                }
        )
        .preferredColorScheme(.dark)
        .statusBarHidden(!showControls)
        .onAppear {
            originalBrightness = Double(UIScreen.main.brightness)
            masterVolume = audioManager.masterVolume
            startWave()
            UIApplication.shared.isIdleTimerDisabled = true
            startClockTimer()
            selectInitialScene()
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            clockTimer?.invalidate()
            UIScreen.main.brightness = CGFloat(originalBrightness)
            orientationManager.restorePortrait()
        }
        .onChange(of: timerManager.isActive) { _, isActive in
            if !isActive { isPresented = false }
        }
        .alert("保存当前场景", isPresented: $showSaveScene) {
            TextField("场景名称", text: $sceneName)
            Button("保存") {
                guard !sceneName.isEmpty else { return }
                Haptics.success()
                let ids = audioManager.activePlayers.map { $0.sound.id }
                var vols: [String: Float] = [:]
                for p in audioManager.activePlayers { vols[p.sound.id] = p.volume }
                sceneManager.saveCurrentScene(name: sceneName, soundIDs: ids, volumes: vols)
                sceneName = ""
            }
            Button("取消", role: .cancel) { sceneName = "" }
        } message: {
            Text("为当前 \(audioManager.activeCount) 种声音的组合起个名字")
        }
    }

    // MARK: - 沉浸布局
    // 视频作为完整背景，时钟始终居中；控制面板以 overlay 浮层显示，不挤占时钟空间。
    private var immersiveLayout: some View {
        ZStack {
            // 时钟始终居中
            clockSection.scaleEffect(clockScale)

            // 顶部栏 + 底部控制面板作为覆盖层
            if showControls {
                VStack(spacing: 0) {
                    StandbyTopBar(
                        timerManager: timerManager,
                        isLandscape: orientationManager.isLandscape,
                        onExit: exitStandby,
                        onStopAll: stopAll,
                        onAddTime: addTime,
                        onToggleOrientation: toggleOrientation
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { }
                    Spacer()
                    immersiveBottomControls
                }
            }
        }
        .frame(maxWidth: 400, maxHeight: .infinity)
    }

    // MARK: - 沉浸模式底部控制区
    // 仅占据内容实际高度，其上方的空白由外层 Spacer 让出，
    // 从而让面板外的空白点击穿透到全屏捕获层以关闭面板。
    private var immersiveBottomControls: some View {
        VStack(spacing: 14) {
            SoundWaveRow(audioManager: audioManager, waveOffset: waveOffset)
            if showMixer {
                StandbyMixer(audioManager: audioManager, onVolumeChange: { })
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            StandbyControlPanel(masterVolume: $masterVolume, brightness: $brightness, audioManager: audioManager, onInteract: { })
            StandbyToolBar(
                showMixer: showMixer,
                clockStyle: clockStyle,
                use24Hour: use24Hour,
                showSeconds: showSeconds,
                showDate: showDate,
                clockScale: clockScale,
                timerIsActive: timerManager.isActive,
                onToggleMixer: { withAnimation(.spring(response: 0.35)) { showMixer.toggle() } },
                onSelectClockStyle: { clockStyleRaw = $0.rawValue },
                onToggle24Hour: { use24Hour = $0 },
                onToggleSeconds: { showSeconds = $0 },
                onToggleDate: { showDate = $0 },
                onSelectClockScale: { clockScale = $0 },
                onStartTimer: { minutes in
                    timerManager.selectedMinutes = minutes
                    timerManager.start { audioManager.stopAll(); isPresented = false }
                },
                onCancelTimer: { timerManager.stop() },
                onSaveScene: { showSaveScene = true }
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.top, 40)
        .padding(.bottom, 36)
        .background(
            LinearGradient(
                colors: [.clear, Color.black.opacity(0.6), Color.black.opacity(0.85)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        )
        .contentShape(Rectangle())
        .onTapGesture { }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - 时钟区域
    @ViewBuilder
    private var clockSection: some View {
        switch clockStyle {
        case .digital:  DigitalClock(time: currentTime, formatter: clockFormatter, primaryColor: primaryColor, showTimerRing: showTimerRing, timerManager: timerManager)
        case .dial:     DialClock(time: currentTime, formatter: clockFormatter, primaryColor: primaryColor, showTimerRing: showTimerRing, timerManager: timerManager)
        case .minimal:  MinimalClock(time: currentTime, formatter: clockFormatter, primaryColor: primaryColor, showTimerRing: showTimerRing, timerManager: timerManager)
        case .split:    SplitClock(time: currentTime, formatter: clockFormatter, primaryColor: primaryColor, showTimerRing: showTimerRing, timerManager: timerManager)
        }
    }

    // MARK: - 交互逻辑
    private func addTime(_ minutes: Int) {
        timerManager.addMinutes(minutes)
    }

    private func toggleControls() {
        withAnimation(.easeInOut(duration: 0.3)) { showControls.toggle() }
    }

    private func dismissControls() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showControls = false
            showMixer = false
        }
    }

    private func startWave() {
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { waveOffset = 4 }
    }

    private func startClockTimer() {
        clockTimer?.invalidate()
        let timer = Foundation.Timer(timeInterval: 1, repeats: true) { _ in currentTime = Date() }
        RunLoop.main.add(timer, forMode: .common)
        clockTimer = timer
    }

    private func selectInitialScene() {
        guard selectedSceneID == nil else { return }
        let activeSoundIDs = Set(audioManager.activePlayers.map { $0.sound.id })
        selectedSceneID = videoScenes.first(where: { Set($0.soundIDs) == activeSoundIDs })?.id ?? videoScenes.first?.id
        selectedVideoVariant = 0
    }

    private func switchVideoVariant(forward: Bool) {
        guard videoVariantCount > 1 else { return }
        let nextVariant = forward
            ? (selectedVideoVariant + 1) % videoVariantCount
            : (selectedVideoVariant - 1 + videoVariantCount) % videoVariantCount
        Haptics.light()
        selectedVideoVariant = nextVariant
    }

    private func toggleOrientation() {
        orientationManager.toggle()
    }

    private func stopAll() {
        Haptics.medium()
        withAnimation(.spring(response: 0.35)) {
            timerManager.stop()
            audioManager.stopAll()
            isPresented = false
        }
    }

    private func exitStandby() { isPresented = false }
}
