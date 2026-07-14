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
    let mode: StandbyMode
    @Binding var isPresented: Bool

    @StateObject private var orientationManager = OrientationManager()

    // 亮度
    @State private var brightness: Double = Double(UIScreen.main.brightness)
    @State private var originalBrightness: Double = Double(UIScreen.main.brightness)

    // 音量
    @State private var masterVolume: Float = 0.8

    // UI 状态
    @State private var showControls = true
    @State private var currentTime = Date()
    @State private var hideTimer: Timer?
    @State private var breathingScale: CGFloat = 1.0
    @State private var waveOffset: CGFloat = 0

    // 迷你混音器
    @State private var showMixer = false

    // 偏好设置
    @AppStorage("standby_use24Hour") private var use24Hour = true
    @AppStorage("standby_showSeconds") private var showSeconds = false
    @AppStorage("standby_showDate") private var showDate = true
    @AppStorage("standby_breathingSpeed") private var breathingSpeedRaw = "正常"
    @AppStorage("standby_autoHide") private var autoHideRaw = "5秒"
    @AppStorage("standby_clockStyle") private var clockStyleRaw = "数字"
    @AppStorage("standby_clockScale") private var clockScale: Double = 1.0

    @State private var clockTimer: Foundation.Timer?

    private var breathingSpeed: BreathingSpeed { BreathingSpeed(rawValue: breathingSpeedRaw) ?? .normal }
    private var autoHide: AutoHideDuration { AutoHideDuration(rawValue: autoHideRaw) ?? .five }
    private var clockStyle: ClockStyle { ClockStyle(rawValue: clockStyleRaw) ?? .digital }
    private var primaryColor: Color { audioManager.activePlayers.first?.sound.color ?? Color(hex: "667eea") }
    private var clockFormatter: ClockTimeFormatter { ClockTimeFormatter(use24Hour: use24Hour, showSeconds: showSeconds, showDate: showDate) }
    private var showTimerRing: Bool { mode == .timer && timerManager.isActive }

    var body: some View {
        ZStack {
            StandbyBackground(
                breathingScale: breathingScale,
                breathingSpeed: breathingSpeed,
                primaryColor: primaryColor,
                activePlayers: audioManager.activePlayers
            )
            .contentShape(Rectangle())
            .onTapGesture { toggleControls() }

            if orientationManager.isLandscape { landscapeLayout } else { portraitLayout }

            if showControls { rotateButton }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden(!showControls)
        .onAppear {
            originalBrightness = Double(UIScreen.main.brightness)
            masterVolume = audioManager.masterVolume
            startBreathing()
            startWave()
            scheduleAutoHide()
            UIApplication.shared.isIdleTimerDisabled = true
            startClockTimer()
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            hideTimer?.invalidate()
            clockTimer?.invalidate()
            UIScreen.main.brightness = CGFloat(originalBrightness)
            orientationManager.restorePortrait()
        }
        .onChange(of: timerManager.isActive) { _, isActive in
            if !isActive { isPresented = false }
        }
    }

    // MARK: - 竖屏布局
    private var portraitLayout: some View {
        VStack(spacing: 0) {
            if showControls { StandbyTopBar(mode: mode, timerManager: timerManager, onExit: exitStandby, onAddTime: addTime) }
            Spacer()
            clockSection.scaleEffect(clockScale)
            Spacer()
            if showControls { bottomControls }
        }
    }

    // MARK: - 横屏布局
    private var landscapeLayout: some View {
        VStack(spacing: 0) {
            if showControls { StandbyTopBar(mode: mode, timerManager: timerManager, onExit: exitStandby, onAddTime: addTime) }
            HStack(spacing: 0) {
                Spacer()
                clockSection.scaleEffect(clockScale)
                Spacer()
                if showControls {
                    VStack(spacing: 12) {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 12) {
                                SoundWaveRow(audioManager: audioManager, waveOffset: waveOffset)
                                if showMixer { StandbyMixer(audioManager: audioManager, onVolumeChange: scheduleAutoHide).transition(.opacity) }
                                StandbyControlPanel(masterVolume: $masterVolume, brightness: $brightness, audioManager: audioManager, onInteract: scheduleAutoHide)
                            }
                            .frame(width: 280)
                            .padding(.trailing, 16)
                            .padding(.bottom, 4)
                        }
                        StandbyToolBar(
                            showMixer: showMixer, clockStyle: clockStyle, breathingSpeed: breathingSpeed, autoHide: autoHide,
                            use24Hour: use24Hour, showSeconds: showSeconds, showDate: showDate, clockScale: clockScale,
                            onToggleMixer: { withAnimation(.spring(response: 0.35)) { showMixer.toggle() }; scheduleAutoHide() },
                            onSelectClockStyle: { clockStyleRaw = $0.rawValue },
                            onToggle24Hour: { use24Hour = $0 },
                            onToggleSeconds: { showSeconds = $0 },
                            onToggleDate: { showDate = $0 },
                            onSelectClockScale: { clockScale = $0 },
                            onSelectBreathingSpeed: { breathingSpeedRaw = $0.rawValue; restartBreathingIfNeeded() },
                            onSelectAutoHide: { autoHideRaw = $0.rawValue; scheduleAutoHide() }
                        )
                        .frame(width: 280)
                        .padding(.trailing, 16)
                        .padding(.bottom, 16)
                    }
                    .frame(width: 300)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
        }
    }

    // MARK: - 旋转按钮
    private var rotateButton: some View {
        VStack {
            HStack {
                Spacer()
                Button {
                    Haptics.light()
                    orientationManager.toggle()
                    scheduleAutoHide()
                } label: {
                    Image(systemName: orientationManager.isLandscape ? "arrow.counterclockwise" : "arrow.clockwise")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.65))
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(.ultraThinMaterial).overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 0.5)))
                }
                .buttonStyle(.plain)
                .padding(.trailing, 16)
                .padding(.top, 52)
            }
            Spacer()
        }
        .transition(.opacity)
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

    // MARK: - 底部控制区
    private var bottomControls: some View {
        VStack(spacing: 14) {
            SoundWaveRow(audioManager: audioManager, waveOffset: waveOffset)
            if showMixer { StandbyMixer(audioManager: audioManager, onVolumeChange: scheduleAutoHide).transition(.move(edge: .bottom).combined(with: .opacity)) }
            StandbyControlPanel(masterVolume: $masterVolume, brightness: $brightness, audioManager: audioManager, onInteract: scheduleAutoHide)
            StandbyToolBar(
                showMixer: showMixer, clockStyle: clockStyle, breathingSpeed: breathingSpeed, autoHide: autoHide,
                use24Hour: use24Hour, showSeconds: showSeconds, showDate: showDate, clockScale: clockScale,
                onToggleMixer: { withAnimation(.spring(response: 0.35)) { showMixer.toggle() }; scheduleAutoHide() },
                onSelectClockStyle: { clockStyleRaw = $0.rawValue },
                onToggle24Hour: { use24Hour = $0 },
                onToggleSeconds: { showSeconds = $0 },
                onToggleDate: { showDate = $0 },
                onSelectClockScale: { clockScale = $0 },
                onSelectBreathingSpeed: { breathingSpeedRaw = $0.rawValue; restartBreathingIfNeeded() },
                onSelectAutoHide: { autoHideRaw = $0.rawValue; scheduleAutoHide() }
            )
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 36)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - 交互逻辑
    private func addTime(_ minutes: Int) {
        timerManager.addMinutes(minutes)
        scheduleAutoHide()
    }

    private func toggleControls() {
        withAnimation(.easeInOut(duration: 0.3)) { showControls.toggle() }
        if showControls { scheduleAutoHide() }
    }

    private func scheduleAutoHide() {
        hideTimer?.invalidate()
        guard let seconds = autoHide.seconds else { return }
        hideTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 0.4)) { showControls = false; showMixer = false }
        }
    }

    private func startBreathing() {
        guard breathingSpeed != .off else { breathingScale = 1.0; return }
        withAnimation(.easeInOut(duration: breathingSpeed.duration).repeatForever(autoreverses: true)) { breathingScale = breathingSpeed.scale }
    }

    private func restartBreathingIfNeeded() {
        breathingScale = 1.0
        if breathingSpeed != .off {
            withAnimation(.easeInOut(duration: breathingSpeed.duration).repeatForever(autoreverses: true)) { breathingScale = breathingSpeed.scale }
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

    private func exitStandby() { isPresented = false }
}
