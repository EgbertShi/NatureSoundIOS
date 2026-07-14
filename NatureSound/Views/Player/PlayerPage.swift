//
//  PlayerPage.swift
//  NatureSound
//
//  Created by egbert on 2026/7/1.
//

import SwiftUI

// MARK: - 全屏播放器页面
struct PlayerPage: View {
    let audioManager: AudioManager
    let timerManager: TimerManager
    let sceneManager: SceneManager
    @Binding var showStandby: Bool
    @Binding var standbyMode: StandbyMode
    @Binding var isPresented: Bool

    @State private var showSaveScene = false
    @State private var showTimerPicker = false
    @State private var sceneName = ""
    @State private var masterVolume: Float = 0.8

    var body: some View {
        ZStack {
            backgroundGradient
            backgroundGlows

            VStack(spacing: 0) {
                topNavigation
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        soundIconsOverview
                        if timerManager.isActive { timerStatusCard }
                        mixerSection
                        masterVolumeSection
                        actionButtonsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { masterVolume = audioManager.masterVolume }
        .sheet(isPresented: $showTimerPicker) {
            TimerStandbyPicker(
                timerManager: timerManager,
                audioManager: audioManager,
                isPresented: $showTimerPicker,
                showStandby: $showStandby,
                onPlayerDismiss: { isPresented = false }
            )
            .presentationDetents([.medium])
            .presentationBackground(.clear)
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

    // MARK: - 背景
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [Color(hex: "0F0C29"), Color(hex: "1A1A2E"), Color(hex: "16213E")],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var backgroundGlows: some View {
        ZStack {
            ForEach(Array(audioManager.activePlayers.prefix(3).enumerated()), id: \.offset) { idx, player in
                Circle()
                    .fill(player.sound.color.opacity(0.06))
                    .frame(width: 250, height: 250)
                    .blur(radius: 70)
                    .offset(x: CGFloat(idx - 1) * 100, y: CGFloat(idx - 1) * 60)
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - 顶部导航
    private var topNavigation: some View {
        ZStack {
            HStack {
                Button {
                    Haptics.light()
                    isPresented = false
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.down").font(.system(size: 14, weight: .semibold))
                        Text("收起").font(.system(size: 14, weight: .medium))
                    }
                    .foregroundStyle(Color.white.opacity(0.6))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
                Spacer()
            }

            Text("播放器")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.7))

            HStack {
                Spacer()
                Button {
                    Haptics.medium()
                    withAnimation(.spring(response: 0.35)) {
                        timerManager.stop()
                        audioManager.stopAll()
                        isPresented = false
                    }
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.7))
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color.red.opacity(0.2)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: - 声音图标总览
    private var soundIconsOverview: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(audioManager.activePlayers) { player in
                    VStack(spacing: 6) {
                        ZStack {
                            Circle().fill(player.sound.color.opacity(0.2)).frame(width: 44, height: 44)
                            Image(systemName: player.sound.icon)
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(player.sound.color)
                        }
                        Text(player.sound.name)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.4))
                            .lineLimit(1)
                    }
                    .frame(width: 52)
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.03)))
    }

    // MARK: - 定时器状态卡片
    private var timerStatusCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "timer").font(.system(size: 20)).foregroundStyle(Color(hex: "FF6B6B"))
            VStack(alignment: .leading, spacing: 2) {
                Text(timerManager.displayTime)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.9))
                Text("后自动停止").font(.system(size: 12)).foregroundStyle(Color.white.opacity(0.4))
            }
            Spacer()
            Button { timerManager.stop() } label: {
                Text("取消")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(hex: "FF6B6B"))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color(hex: "FF6B6B").opacity(0.12)))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(hex: "FF6B6B").opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "FF6B6B").opacity(0.15), lineWidth: 1))
        )
    }

    // MARK: - 混音器
    private var mixerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "slider.horizontal.3").font(.system(size: 14)).foregroundStyle(Color.white.opacity(0.5))
                Text("混音器").font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.white.opacity(0.8))
                Spacer()
                Text("\(audioManager.activeCount) 种声音").font(.system(size: 12, weight: .medium)).foregroundStyle(Color.white.opacity(0.35))
            }
            VStack(spacing: 0) {
                ForEach(Array(audioManager.activePlayers.enumerated()), id: \.element.id) { index, player in
                    ActiveSoundRow(player: player) {
                        withAnimation(.spring(response: 0.3)) { audioManager.toggle(player.sound) }
                    }
                    if index < audioManager.activePlayers.count - 1 {
                        Divider().background(Color.white.opacity(0.05)).padding(.horizontal, 16)
                    }
                }
            }
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.03)))
        }
    }

    // MARK: - 主音量
    private var masterVolumeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "speaker.wave.2.fill").font(.system(size: 14)).foregroundStyle(Color.white.opacity(0.5))
                Text("主音量").font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.white.opacity(0.8))
                Spacer()
                Text("\(Int(masterVolume * 100))%").font(.system(size: 13, weight: .medium, design: .monospaced)).foregroundStyle(Color.white.opacity(0.4))
            }
            Slider(value: Binding(
                get: { Double(masterVolume) },
                set: { newValue in masterVolume = Float(newValue); audioManager.updateMasterVolume(masterVolume) }
            ), in: 0...1)
            .tint(Color(hex: "667eea"))
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.03)))
    }

    // MARK: - 功能按钮
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            actionButton(icon: "moon.stars.fill", iconColor: Color(hex: "667eea"), title: "沉浸模式", subtitle: "进入待机，屏幕常亮，持续播放") {
                Haptics.medium()
                standbyMode = .immersive
                isPresented = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { showStandby = true }
            }
            actionButton(icon: "timer", iconColor: Color(hex: "FF6B6B"), title: "定时待机", subtitle: "选择时长，到时间自动停止") {
                Haptics.light()
                standbyMode = .timer
                showTimerPicker = true
            }
            actionButton(icon: "star", iconColor: Color(hex: "FFD54F"), title: "保存为场景", subtitle: "将当前声音组合保存以便快速使用") {
                Haptics.light()
                showSaveScene = true
            }
        }
    }

    private func actionButton(icon: String, iconColor: Color, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 18)).foregroundStyle(iconColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.white.opacity(0.9))
                    Text(subtitle).font(.system(size: 12)).foregroundStyle(Color.white.opacity(0.4))
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(Color.white.opacity(0.3))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.03))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.06), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }
}
