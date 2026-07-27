//
//  StandbyView.swift
//  NatureSound
//
//  Created by egbert on 2026/7/11.
//

import SwiftUI
import UIKit
internal import Combine

// MARK: - 展开面板类型
private enum ExpandedPanel: Equatable {
    case mixer
    case timer
    case clock
    case scene
}

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

    // 展开的面板（互斥）
    @State private var expandedPanel: ExpandedPanel? = nil

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
    private var videoScenes: [ScenePreset] { ScenePreset.allPresets.filter { videoManager.hasAsset(for: $0.id) } }
    private var selectedScene: ScenePreset? { videoScenes.first { $0.id == selectedSceneID } }
    private var videoVariantCount: Int { selectedScene.map { videoManager.videoVariantCount(for: $0.id) } ?? 0 }

    // 实际布局方向：以 GeometryReader 的真实宽高为准，避免旋转请求与 SwiftUI 布局不同步
    @State private var isLandscape: Bool = false

    // 从 window 获取安全区域，避免 .ignoresSafeArea() 后 GeometryReader 返回 0
    private var windowSafeTop: CGFloat {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?
            .keyWindow?.safeAreaInsets.top ?? 59
    }

    // 横屏时的左侧安全区域（刘海侧）
    private var windowSafeLeading: CGFloat {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?
            .keyWindow?.safeAreaInsets.left ?? 0
    }

    // 横屏时的右侧安全区域
    private var windowSafeTrailing: CGFloat {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?
            .keyWindow?.safeAreaInsets.right ?? 0
    }

    var body: some View {
        GeometryReader { geo in
            let safeW = geo.size.width
            let safeH = geo.size.height
            let topInset = windowSafeTop
            let landscape = safeW > safeH

            ZStack {
                // MARK: 背景
                backgroundLayer

                // 视频翻页指示器 — 在控制面板层级下面
                VStack {
                    Spacer()
                    VideoPageIndicator(count: videoVariantCount, current: selectedVideoVariant)
                        .padding(.bottom, landscape ? 12 : 36)
                }
                .frame(width: safeW, height: safeH)
                .allowsHitTesting(false)

                // 点击背景关闭控制面板
                if showControls {
                    Color.black.opacity(0.001)
                        .frame(width: safeW, height: safeH)
                        .contentShape(Rectangle())
                        .onTapGesture { dismissControls() }
                }

                // MARK: 根据横竖屏使用不同布局（在指示器之上）
                if landscape {
                    landscapeBody(w: safeW, h: safeH, topInset: topInset)
                } else {
                    portraitBody(w: safeW, h: safeH, topInset: topInset)
                }
            }
            .frame(width: safeW, height: safeH)
            .onAppear { isLandscape = landscape }
            .onChange(of: geo.size) { _, newSize in isLandscape = newSize.width > newSize.height }
        }
        .ignoresSafeArea()
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
    }

    // MARK: - 背景层
    private var backgroundLayer: some View {
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
    }

    // MARK: - 竖屏布局
    private func portraitBody(w: CGFloat, h: CGFloat, topInset: CGFloat) -> some View {
        // 控制面板最大宽度限制，避免在大屏上过宽
        let controlWidth = min(w - 32, 380.0)

        return ZStack {
            // 时钟居中
            clockSection
                .scaleEffect(clockScale)
                .frame(width: w, height: h)
                .offset(y: showControls ? -h * 0.08 : 0)
                .animation(.easeInOut(duration: 0.3), value: showControls)

            if showControls {
                VStack(spacing: 0) {
                    Spacer().frame(height: topInset) // 安全区域顶部内边距

                    // 顶部栏
                    topBarView(landscape: false)
                        .frame(width: w)

                    Spacer()

                    // 底部控制区
                    VStack(spacing: 10) {
                        SoundWaveRow(audioManager: audioManager, waveOffset: waveOffset)

                        if let panel = expandedPanel {
                            expandedPanelView(panel, isLandscape: false)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }

                        StandbyControlPanel(
                            masterVolume: $masterVolume,
                            brightness: $brightness,
                            audioManager: audioManager,
                            onInteract: { }
                        )

                        toolBarView
                    }
                    .frame(width: controlWidth)
                    .padding(.top, 30)
                    .padding(.bottom, 30)
                    .frame(maxWidth: .infinity) // 居中
                    .background(
                        LinearGradient(
                            colors: [.clear, Color.black.opacity(0.55), Color.black.opacity(0.8)],
                            startPoint: .top, endPoint: .bottom
                        )
                        .ignoresSafeArea(edges: .bottom)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { }
                }
                .frame(width: w, height: h)
                .transition(.opacity)
            }
        }
        .frame(width: w, height: h)
    }

    // MARK: - 横屏布局
    private func landscapeBody(w: CGFloat, h: CGFloat, topInset: CGFloat) -> some View {
        let leadingInset = windowSafeLeading
        let trailingInset = windowSafeTrailing
        let sideW = min(300.0, w * 0.4)
        let clockAreaW = w - (showControls ? sideW : 0)

        return ZStack {
            // 时钟 — 偏左
            clockSection
                .scaleEffect(clockScale)
                .frame(width: clockAreaW, height: h)
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(.easeInOut(duration: 0.3), value: showControls)

            if showControls {
                // 顶部栏：横跨时钟区域（不覆盖侧边栏），考虑横屏安全区域
                VStack(spacing: 0) {
                    topBarView(landscape: true)
                        .padding(.leading, leadingInset)
                        .frame(width: clockAreaW)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer()
                }
                .padding(.top, topInset > 0 ? topInset : 8)
                .frame(width: w, height: h)

                // 右侧侧边栏
                HStack(spacing: 0) {
                    Spacer()
                    landscapeSidePanelView(width: sideW, height: h)
                        .padding(.trailing, trailingInset)
                }
                .frame(width: w, height: h)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .frame(width: w, height: h)
    }

    // MARK: 横屏右侧面板
    private func landscapeSidePanelView(width: CGFloat, height: CGFloat) -> some View {
        let contentW = width - 28 // 左右各 14 内边距

        return ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 10) {
                SoundWaveRow(audioManager: audioManager, waveOffset: waveOffset)

                if let panel = expandedPanel {
                    expandedPanelView(panel, isLandscape: true)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }

                StandbyControlPanelLandscape(
                    masterVolume: $masterVolume,
                    brightness: $brightness,
                    audioManager: audioManager,
                    onInteract: { }
                )

                toolBarView
            }
            .frame(width: contentW)
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 14)
        }
        .frame(width: width, height: height)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.5), Color.black.opacity(0.75), Color.black.opacity(0.85)],
                startPoint: .leading, endPoint: .trailing
            )
        )
        .contentShape(Rectangle())
        .onTapGesture { }
    }

    // MARK: - 公共子组件

    private func topBarView(landscape: Bool) -> some View {
        StandbyTopBar(
            timerManager: timerManager,
            isLandscape: landscape,
            onExit: exitStandby,
            onStopAll: stopAll,
            onAddTime: addTime,
            onToggleOrientation: toggleOrientation
        )
    }

    private var toolBarView: some View {
        StandbyToolBar(
            showMixer: expandedPanel == .mixer,
            showTimer: expandedPanel == .timer,
            showClock: expandedPanel == .clock,
            showScene: expandedPanel == .scene,
            timerIsActive: timerManager.isActive,
            audioManager: audioManager,
            onToggleMixer: { togglePanel(.mixer) },
            onToggleTimer: { togglePanel(.timer) },
            onToggleClock: { togglePanel(.clock) },
            onToggleScene: { togglePanel(.scene) }
        )
    }

    // MARK: - 展开面板
    @ViewBuilder
    private func expandedPanelView(_ panel: ExpandedPanel, isLandscape: Bool) -> some View {
        switch panel {
        case .mixer:
            StandbyMixer(audioManager: audioManager, onVolumeChange: { })
        case .timer:
            StandbyTimerPanel(
                timerManager: timerManager,
                isLandscape: isLandscape,
                onStartTimer: { minutes in
                    timerManager.selectedMinutes = minutes
                    timerManager.start { audioManager.stopAll(); isPresented = false }
                },
                onCancelTimer: { timerManager.stop() },
                onAddTime: addTime,
                onInteract: { }
            )
        case .clock:
            StandbyClockPanel(
                clockStyle: clockStyle,
                use24Hour: use24Hour,
                showSeconds: showSeconds,
                showDate: showDate,
                clockScale: clockScale,
                isLandscape: isLandscape,
                onSelectClockStyle: { clockStyleRaw = $0.rawValue },
                onToggle24Hour: { use24Hour = $0 },
                onToggleSeconds: { showSeconds = $0 },
                onToggleDate: { showDate = $0 },
                onSelectClockScale: { clockScale = $0 },
                onInteract: { }
            )
        case .scene:
            StandbyScenePanel(
                audioManager: audioManager,
                sceneManager: sceneManager,
                onInteract: { },
                onDismiss: { withAnimation(.spring(response: 0.35)) { expandedPanel = nil } }
            )
        }
    }

    // MARK: - 时钟区域
    @ViewBuilder
    private var clockSection: some View {
        switch clockStyle {
        case .digital:  DigitalClock(time: currentTime, formatter: clockFormatter, primaryColor: primaryColor, timerManager: timerManager)
        case .dial:     DialClock(time: currentTime, formatter: clockFormatter, primaryColor: primaryColor, timerManager: timerManager)
        case .minimal:  MinimalClock(time: currentTime, formatter: clockFormatter, primaryColor: primaryColor, timerManager: timerManager)
        case .split:    SplitClock(time: currentTime, formatter: clockFormatter, primaryColor: primaryColor, timerManager: timerManager)
        }
    }

    // MARK: - 面板切换
    private func togglePanel(_ panel: ExpandedPanel) {
        withAnimation(.spring(response: 0.35)) {
            expandedPanel = expandedPanel == panel ? nil : panel
        }
    }

    // MARK: - 交互逻辑
    private func addTime(_ minutes: Int) { timerManager.addMinutes(minutes) }

    private func toggleControls() {
        withAnimation(.easeInOut(duration: 0.3)) { showControls.toggle() }
    }

    private func dismissControls() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showControls = false
            expandedPanel = nil
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

    private func toggleOrientation() { orientationManager.toggle() }

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
