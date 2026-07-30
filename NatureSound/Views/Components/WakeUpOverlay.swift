//
//  WakeUpOverlay.swift
//  NatureSound
//
//  Created by egbert on 2026/7/30.
//

import SwiftUI
import AVFoundation

// MARK: - 唤醒 Overlay
/// 定时结束后（非入睡模式）弹出的半透明唤醒窗口。
/// 毛玻璃背景 + 居中卡片布局，播放唤醒提示音并提供「继续」「停止」两个选项。
struct WakeUpOverlay: View {
    let timerManager: TimerManager
    let audioManager: AudioManager
    let onContinue: () -> Void
    let onStop: () -> Void

    @State private var wakeUpPlayer: AVAudioPlayer?
    @State private var showContent = false
    @State private var ringScale: CGFloat = 0.6
    @State private var ringOpacity: Double = 0

    private var mode: FocusMode { timerManager.currentMode ?? .focus }
    private var totalMinutes: Int { timerManager.totalMinutes }

    var body: some View {
        ZStack {
            // MARK: 背景层 — 半透明 + 模糊
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture {} // 拦截穿透

            // MARK: 呼吸光环（背景装饰）
            Circle()
                .fill(
                    RadialGradient(
                        colors: [mode.themeColor.opacity(0.2), mode.themeColor.opacity(0)],
                        center: .center,
                        startRadius: 40,
                        endRadius: 180
                    )
                )
                .frame(width: 360, height: 360)
                .scaleEffect(ringScale)
                .opacity(ringOpacity)

            // MARK: 内容卡片
            if showContent {
                VStack(spacing: 0) {
                    // 图标区域
                    ZStack {
                        Circle()
                            .fill(mode.themeColor.opacity(0.12))
                            .frame(width: 80, height: 80)

                        Image(systemName: mode.icon)
                            .font(.system(size: 32, weight: .medium))
                            .foregroundStyle(mode.themeColor)
                    }
                    .padding(.top, 36)

                    // 标题文案
                    VStack(spacing: 6) {
                        Text("\(mode.displayName)时间已结束")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)

                        Text("你已\(mode.displayName)了 \(totalMinutes) 分钟")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    .padding(.top, 20)

                    // 操作按钮区
                    VStack(spacing: 10) {
                        Button {
                            Haptics.medium()
                            stopWakeUpSound()
                            onContinue()
                        } label: {
                            Text("继续播放")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(mode.themeColor)
                                )
                        }
                        .buttonStyle(.plain)

                        Button {
                            Haptics.light()
                            stopWakeUpSound()
                            onStop()
                        } label: {
                            Text("停止")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.7))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(.white.opacity(0.08))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 28)

                    // 唤醒铃声提示
                    HStack(spacing: 4) {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 9))
                        Text(timerManager.selectedWakeUpTone.name)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(.white.opacity(0.25))
                    .padding(.top, 16)
                    .padding(.bottom, 28)
                }
                .frame(maxWidth: 320)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(.white.opacity(0.1), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.3), radius: 40, y: 10)
                .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .center)))
            }
        }
        .onAppear {
            // 内容入场
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                showContent = true
            }
            // 呼吸光环
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                ringScale = 1.15
                ringOpacity = 0.8
            }
            Haptics.medium()
            playWakeUpSound()
        }
        .onDisappear {
            stopWakeUpSound()
        }
    }

    // MARK: - 唤醒铃声

    private func playWakeUpSound() {
        let tone = timerManager.selectedWakeUpTone
        guard let url = Bundle.main.url(
            forResource: tone.fileName,
            withExtension: "m4a",
            subdirectory: "Sounds/\(tone.category)"
        ) else { return }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = 0.5
            player.numberOfLoops = 3
            player.prepareToPlay()
            player.play()
            wakeUpPlayer = player
        } catch {
            // 铃声播放失败不阻塞唤醒流程
        }
    }

    private func stopWakeUpSound() {
        wakeUpPlayer?.stop()
        wakeUpPlayer = nil
    }
}
