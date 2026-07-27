//
//  StandbyControls.swift
//  NatureSound
//
//  Created by egbert on 2026/7/11.
//

import SwiftUI

// MARK: - 公共面板背景
private struct PanelBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
            )
    }
}

// MARK: - 声音波形行
struct SoundWaveRow: View {
    let audioManager: AudioManager
    let waveOffset: CGFloat

    var body: some View {
        HStack(spacing: 16) {
            ForEach(Array(audioManager.activePlayers.prefix(7).enumerated()), id: \.offset) { idx, player in
                VStack(spacing: 4) {
                    Image(systemName: player.sound.icon)
                        .font(.system(size: 13))
                        .foregroundStyle(player.sound.color.opacity(0.6))
                    RoundedRectangle(cornerRadius: 1)
                        .fill(player.sound.color.opacity(0.3))
                        .frame(width: 2, height: CGFloat(5 + (idx % 3) * 3))
                        .offset(y: waveOffset * CGFloat((idx % 2 == 0 ? 1 : -1)))
                }
            }
        }
        .transition(.opacity)
    }
}

// MARK: - 迷你混音器
struct StandbyMixer: View {
    let audioManager: AudioManager
    let onVolumeChange: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("混音器")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.5))
                Spacer()
                Text("\(audioManager.activeCount) 种声音")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.3))
            }
            VStack(spacing: 8) {
                ForEach(audioManager.activePlayers) { player in
                    mixerRow(player)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(PanelBackground())
    }

    private func mixerRow(_ player: SoundPlayer) -> some View {
        HStack(spacing: 8) {
            Circle().fill(player.sound.color.opacity(0.6)).frame(width: 7, height: 7)
            Text(player.sound.name)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.6))
                .lineLimit(1)
                .frame(width: 48, alignment: .leading)
            if audioManager.spatialMode != .off {
                Text(player.channelLabel)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(hex: "667eea"))
                    .frame(width: 14, height: 14)
                    .background(Circle().fill(Color(hex: "667eea").opacity(0.15)))
            }
            Slider(value: Binding(
                get: { Double(player.volume) },
                set: { newValue in
                    let v = Float(newValue)
                    player.volume = v
                    player.updateVolume(v * audioManager.masterVolume)
                    onVolumeChange()
                }
            ), in: 0...1)
            .tint(player.sound.color.opacity(0.7))
            Text("\(Int(player.volume * 100))")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.3))
                .frame(width: 24, alignment: .trailing)
            Button {
                Haptics.light()
                withAnimation(.spring(response: 0.3)) { audioManager.removeSound(player.sound) }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.white.opacity(0.3))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("移除\(player.sound.name)")
        }
    }
}

// MARK: - 主控制面板（竖屏）
struct StandbyControlPanel: View {
    @Binding var masterVolume: Float
    @Binding var brightness: Double
    let audioManager: AudioManager
    let onInteract: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            // 音量行
            HStack(spacing: 8) {
                Image(systemName: "speaker.wave.1.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.4))
                    .frame(width: 18)
                Slider(value: Binding(
                    get: { Double(masterVolume) },
                    set: { masterVolume = Float($0); audioManager.updateMasterVolume(masterVolume); onInteract() }
                ), in: 0...1)
                .tint(LinearGradient(colors: [Color(hex: "667eea"), Color(hex: "764ba2")], startPoint: .leading, endPoint: .trailing))
                Text("\(Int(masterVolume * 100))%")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.4))
                    .frame(width: 36, alignment: .trailing)
            }

            // 亮度行
            HStack(spacing: 8) {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.4))
                    .frame(width: 18)
                Slider(value: Binding(
                    get: { brightness },
                    set: { brightness = $0; UIScreen.main.brightness = CGFloat($0); onInteract() }
                ), in: 0.05...1)
                .tint(LinearGradient(colors: [Color(hex: "FFD54F"), Color(hex: "FF8E53")], startPoint: .leading, endPoint: .trailing))
                Button {
                    Haptics.soft()
                    withAnimation(.easeInOut(duration: 0.4)) { brightness = 0.05; UIScreen.main.brightness = 0.05 }
                    onInteract()
                } label: {
                    Image(systemName: brightness < 0.1 ? "moon.fill" : "moon")
                        .font(.system(size: 11))
                        .foregroundStyle(brightness < 0.1 ? Color(hex: "667eea") : Color.white.opacity(0.4))
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(brightness < 0.1 ? Color(hex: "667eea").opacity(0.15) : Color.white.opacity(0.06)))
                }
                .buttonStyle(.plain)
                Text("\(Int(brightness * 100))%")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.4))
                    .frame(width: 36, alignment: .trailing)
            }

            // 空间音效行
            HStack(spacing: 6) {
                Image(systemName: "airpodspro")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.4))
                    .frame(width: 18)
                ForEach(SpatialMode.allCases) { mode in
                    spatialChip(mode)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(PanelBackground())
    }

    private func spatialChip(_ mode: SpatialMode) -> some View {
        let selected = audioManager.spatialMode == mode
        return Button {
            Haptics.light()
            audioManager.setSpatialMode(mode)
            onInteract()
        } label: {
            HStack(spacing: 3) {
                Image(systemName: mode.icon).font(.system(size: 11))
                Text(mode.rawValue).font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(selected ? Color(hex: "667eea") : Color.white.opacity(0.4))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(selected ? Color(hex: "667eea").opacity(0.15) : Color.white.opacity(0.05))
                    .overlay(Capsule().stroke(selected ? Color(hex: "667eea").opacity(0.35) : Color.white.opacity(0.06), lineWidth: 0.5))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 横屏控制面板
struct StandbyControlPanelLandscape: View {
    @Binding var masterVolume: Float
    @Binding var brightness: Double
    let audioManager: AudioManager
    let onInteract: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            // 音量
            HStack(spacing: 8) {
                Image(systemName: "speaker.wave.1.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.4))
                    .frame(width: 16)
                Slider(value: Binding(
                    get: { Double(masterVolume) },
                    set: { masterVolume = Float($0); audioManager.updateMasterVolume(masterVolume); onInteract() }
                ), in: 0...1)
                .tint(LinearGradient(colors: [Color(hex: "667eea"), Color(hex: "764ba2")], startPoint: .leading, endPoint: .trailing))
                Text("\(Int(masterVolume * 100))%")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.4))
                    .frame(width: 32, alignment: .trailing)
            }

            // 亮度
            HStack(spacing: 8) {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.4))
                    .frame(width: 16)
                Slider(value: Binding(
                    get: { brightness },
                    set: { brightness = $0; UIScreen.main.brightness = CGFloat($0); onInteract() }
                ), in: 0.05...1)
                .tint(LinearGradient(colors: [Color(hex: "FFD54F"), Color(hex: "FF8E53")], startPoint: .leading, endPoint: .trailing))
                Button {
                    Haptics.soft()
                    withAnimation(.easeInOut(duration: 0.4)) { brightness = 0.05; UIScreen.main.brightness = 0.05 }
                    onInteract()
                } label: {
                    Image(systemName: brightness < 0.1 ? "moon.fill" : "moon")
                        .font(.system(size: 11))
                        .foregroundStyle(brightness < 0.1 ? Color(hex: "667eea") : Color.white.opacity(0.4))
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(brightness < 0.1 ? Color(hex: "667eea").opacity(0.15) : Color.white.opacity(0.06)))
                }
                .buttonStyle(.plain)
                Text("\(Int(brightness * 100))%")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.4))
                    .frame(width: 32, alignment: .trailing)
            }

            // 空间音效
            HStack(spacing: 5) {
                Image(systemName: "airpodspro")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.4))
                    .frame(width: 16)
                ForEach(SpatialMode.allCases) { mode in
                    let selected = audioManager.spatialMode == mode
                    Button {
                        Haptics.light()
                        audioManager.setSpatialMode(mode)
                        onInteract()
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: mode.icon).font(.system(size: 10))
                            Text(mode.rawValue).font(.system(size: 9, weight: .medium))
                        }
                        .foregroundStyle(selected ? Color(hex: "667eea") : Color.white.opacity(0.4))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(selected ? Color(hex: "667eea").opacity(0.15) : Color.white.opacity(0.05))
                                .overlay(Capsule().stroke(selected ? Color(hex: "667eea").opacity(0.35) : Color.white.opacity(0.06), lineWidth: 0.5))
                        )
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(PanelBackground())
    }
}

// MARK: - 定时器面板
struct StandbyTimerPanel: View {
    let timerManager: TimerManager
    let isLandscape: Bool
    let onStartTimer: (Int) -> Void
    let onCancelTimer: () -> Void
    let onAddTime: (Int) -> Void
    let onInteract: () -> Void

    private let quickPresets: [Int] = [10, 15, 20, 30, 45, 60]
    private let morePresets: [Int] = [5, 90, 120]
    @State private var showMore = false

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "timer")
                    .font(.system(size: 12))
                    .foregroundStyle(timerManager.isActive ? Color(hex: "FF6B6B") : Color.white.opacity(0.4))
                Text("定时关闭")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.6))
                Spacer()
                if timerManager.isActive {
                    Text(timerManager.displayTime)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(hex: "FF6B6B").opacity(0.9))
                        .contentTransition(.numericText())
                }
            }

            if timerManager.isActive {
                timerActiveView
            } else {
                timerPresetGrid
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(
                    timerManager.isActive ? Color(hex: "FF6B6B").opacity(0.15) : Color.white.opacity(0.06),
                    lineWidth: 0.5
                ))
        )
        .animation(.spring(response: 0.35), value: timerManager.isActive)
        .animation(.spring(response: 0.3), value: showMore)
    }

    private var timerPresetGrid: some View {
        VStack(spacing: 6) {
            let cols = isLandscape
                ? Array(repeating: GridItem(.flexible(), spacing: 6), count: 6)
                : Array(repeating: GridItem(.flexible(), spacing: 6), count: 3)
            LazyVGrid(columns: cols, spacing: 6) {
                ForEach(quickPresets, id: \.self) { m in presetBtn(m) }
            }
            if !showMore {
                Button {
                    Haptics.light(); showMore = true
                } label: {
                    HStack(spacing: 3) {
                        Text("更多").font(.system(size: 10, weight: .medium))
                        Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold))
                    }
                    .foregroundStyle(Color.white.opacity(0.3))
                    .padding(.top, 2)
                }
                .buttonStyle(.plain)
            } else {
                HStack(spacing: 6) {
                    ForEach(morePresets, id: \.self) { m in presetBtn(m) }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private func presetBtn(_ minutes: Int) -> some View {
        Button {
            Haptics.medium(); onStartTimer(minutes); onInteract()
        } label: {
            VStack(spacing: 1) {
                Text("\(minutes)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.8))
                Text("分钟")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.3))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.05))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.08), lineWidth: 0.5))
            )
        }
        .buttonStyle(.plain)
    }

    private var timerActiveView: some View {
        VStack(spacing: 10) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.08))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(LinearGradient(colors: [Color(hex: "FF6B6B"), Color(hex: "FF8E53")], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * timerManager.progress)
                        .animation(.linear(duration: 1), value: timerManager.progress)
                }
            }
            .frame(height: 3)

            HStack(spacing: 8) {
                ForEach([5, 10], id: \.self) { m in
                    Button {
                        Haptics.medium(); onAddTime(m); onInteract()
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "plus").font(.system(size: 9, weight: .bold))
                            Text("\(m)分钟").font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(Color(hex: "FF8E53"))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(Color(hex: "FF8E53").opacity(0.12))
                                .overlay(Capsule().stroke(Color(hex: "FF8E53").opacity(0.2), lineWidth: 0.5))
                        )
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Button {
                    Haptics.light(); onCancelTimer(); onInteract()
                } label: {
                    Text("取消").font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.5))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.white.opacity(0.06)))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - 时钟样式面板
struct StandbyClockPanel: View {
    let clockStyle: ClockStyle
    let use24Hour: Bool
    let showSeconds: Bool
    let showDate: Bool
    let clockScale: Double
    let isLandscape: Bool

    let onSelectClockStyle: (ClockStyle) -> Void
    let onToggle24Hour: (Bool) -> Void
    let onToggleSeconds: (Bool) -> Void
    let onToggleDate: (Bool) -> Void
    let onSelectClockScale: (Double) -> Void
    let onInteract: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "clock").font(.system(size: 12)).foregroundStyle(Color.white.opacity(0.4))
                Text("时钟样式").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.white.opacity(0.6))
                Spacer()
            }

            // 样式选择
            HStack(spacing: 8) {
                ForEach(ClockStyle.allCases, id: \.self) { style in
                    clockStyleCard(style)
                }
            }

            // 显示选项 + 大小选项
            HStack(spacing: 4) {
                Text("显示").font(.system(size: 10, weight: .medium)).foregroundStyle(Color.white.opacity(0.3))
                chip("24h", isOn: use24Hour) { onToggle24Hour(!use24Hour); onInteract() }
                chip("秒", isOn: showSeconds) { onToggleSeconds(!showSeconds); onInteract() }
                chip("日期", isOn: showDate) { onToggleDate(!showDate); onInteract() }
                Spacer(minLength: 4)
                Text("大小").font(.system(size: 10, weight: .medium)).foregroundStyle(Color.white.opacity(0.3))
                ForEach([("小", 0.8), ("中", 1.0), ("大", 1.3)], id: \.0) { label, scale in
                    chip(label, isOn: abs(clockScale - scale) < 0.05) { onSelectClockScale(scale); onInteract() }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(PanelBackground())
    }

    private func clockStyleCard(_ style: ClockStyle) -> some View {
        let selected = clockStyle == style
        return Button {
            Haptics.light()
            withAnimation(.spring(response: 0.3)) { onSelectClockStyle(style) }
            onInteract()
        } label: {
            VStack(spacing: 5) {
                Image(systemName: style.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(selected ? Color(hex: "667eea") : Color.white.opacity(0.35))
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(selected ? Color(hex: "667eea").opacity(0.15) : Color.white.opacity(0.04))
                    )
                Text(style.rawValue)
                    .font(.system(size: 10, weight: selected ? .bold : .medium))
                    .foregroundStyle(selected ? Color.white.opacity(0.85) : Color.white.opacity(0.35))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selected ? Color(hex: "667eea").opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func chip(_ label: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button { Haptics.light(); action() } label: {
            Text(label)
                .font(.system(size: 10, weight: isOn ? .bold : .medium))
                .foregroundStyle(isOn ? Color(hex: "667eea") : Color.white.opacity(0.35))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(isOn ? Color(hex: "667eea").opacity(0.15) : Color.white.opacity(0.04))
                        .overlay(Capsule().stroke(isOn ? Color(hex: "667eea").opacity(0.3) : Color.white.opacity(0.06), lineWidth: 0.5))
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 场景保存面板
struct StandbyScenePanel: View {
    let audioManager: AudioManager
    let sceneManager: SceneManager
    let onInteract: () -> Void
    let onDismiss: () -> Void

    @State private var sceneName = ""
    @State private var saved = false
    @FocusState private var nameFieldFocused: Bool

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "star.fill").font(.system(size: 12)).foregroundStyle(Color(hex: "FFD54F").opacity(0.8))
                Text("保存当前场景").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.white.opacity(0.6))
                Spacer()
                Button { Haptics.light(); onDismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.3))
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Color.white.opacity(0.06)))
                }
                .buttonStyle(.plain)
            }

            if saved {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 18)).foregroundStyle(Color(hex: "5DAE7A"))
                    Text("场景已保存").font(.system(size: 13, weight: .medium)).foregroundStyle(Color.white.opacity(0.7))
                }
                .padding(.vertical, 6)
                .transition(.scale.combined(with: .opacity))
            } else {
                // 当前声音预览
                HStack(spacing: 6) {
                    ForEach(audioManager.activePlayers.prefix(5)) { player in
                        VStack(spacing: 3) {
                            Image(systemName: player.sound.icon).font(.system(size: 12)).foregroundStyle(player.sound.color.opacity(0.7))
                            Text(player.sound.name).font(.system(size: 8)).foregroundStyle(Color.white.opacity(0.3)).lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    if audioManager.activeCount > 5 {
                        Text("+\(audioManager.activeCount - 5)").font(.system(size: 11, weight: .medium)).foregroundStyle(Color.white.opacity(0.3))
                    }
                }

                // 输入
                HStack(spacing: 8) {
                    TextField("", text: $sceneName, prompt: Text("为场景起个名字…").foregroundStyle(Color.white.opacity(0.2)))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.8))
                        .focused($nameFieldFocused)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white.opacity(0.05))
                                .overlay(RoundedRectangle(cornerRadius: 10)
                                    .stroke(nameFieldFocused ? Color(hex: "667eea").opacity(0.4) : Color.white.opacity(0.08), lineWidth: 0.5))
                        )
                        .onSubmit { saveScene() }

                    Button { saveScene() } label: {
                        Image(systemName: "checkmark").font(.system(size: 13, weight: .bold))
                            .foregroundStyle(sceneName.isEmpty ? Color.white.opacity(0.2) : Color.white)
                            .frame(width: 36, height: 36)
                            .background(RoundedRectangle(cornerRadius: 10).fill(sceneName.isEmpty ? Color.white.opacity(0.05) : Color(hex: "667eea")))
                    }
                    .buttonStyle(.plain)
                    .disabled(sceneName.isEmpty)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: "FFD54F").opacity(0.12), lineWidth: 0.5))
        )
        .onAppear { nameFieldFocused = true }
    }

    private func saveScene() {
        guard !sceneName.isEmpty else { return }
        Haptics.success()
        let ids = audioManager.activePlayers.map { $0.sound.id }
        var vols: [String: Float] = [:]
        for p in audioManager.activePlayers { vols[p.sound.id] = p.volume }
        sceneManager.saveCurrentScene(name: sceneName, soundIDs: ids, volumes: vols)
        withAnimation(.spring(response: 0.35)) { saved = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { onDismiss() }
    }
}

// MARK: - 工具栏
struct StandbyToolBar: View {
    let showMixer: Bool
    let showTimer: Bool
    let showClock: Bool
    let showScene: Bool
    let timerIsActive: Bool
    let audioManager: AudioManager

    let onToggleMixer: () -> Void
    let onToggleTimer: () -> Void
    let onToggleClock: () -> Void
    let onToggleScene: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            toolBtn(icon: "slider.horizontal.3", label: "混音器", on: showMixer, color: Color(hex: "667eea"), action: onToggleMixer)
            toolBtn(icon: "timer", label: "定时", on: showTimer || timerIsActive, color: timerIsActive ? Color(hex: "FF6B6B") : Color(hex: "667eea"), action: onToggleTimer)
            toolBtn(icon: "clock", label: "时钟", on: showClock, color: Color(hex: "667eea"), action: onToggleClock)
            toolBtn(icon: "star", label: "场景", on: showScene, color: Color(hex: "FFD54F"), action: onToggleScene)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .background(PanelBackground())
    }

    private func toolBtn(icon: String, label: String, on: Bool, color: Color, action: @escaping () -> Void) -> some View {
        Button { Haptics.light(); action() } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .symbolRenderingMode(.monochrome)
                    .font(.system(size: 15))
                    .foregroundStyle(on ? color : Color.white.opacity(0.4))
                    .frame(width: 32, height: 32)
                    .background(
                        Circle().fill(on ? color.opacity(0.12) : Color.clear)
                    )
                Text(label)
                    .font(.system(size: 9, weight: on ? .semibold : .medium))
                    .foregroundStyle(on ? color.opacity(0.8) : Color.white.opacity(0.3))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 顶部栏
struct StandbyTopBar: View {
    let timerManager: TimerManager
    let isLandscape: Bool
    let onExit: () -> Void
    let onStopAll: () -> Void
    let onAddTime: (Int) -> Void
    let onToggleOrientation: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button { Haptics.light(); onExit() } label: {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.left").font(.system(size: 12, weight: .bold))
                    Text("退出").font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(Color.white.opacity(0.6))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Capsule().fill(.ultraThinMaterial).overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 0.5)))
            }
            .buttonStyle(.plain)

            if isLandscape {
                Spacer().frame(width: 200)
            } else {
                Spacer()
            }

            Button { Haptics.light(); onToggleOrientation() } label: {
                Image(systemName: isLandscape ? "rectangle.portrait" : "rectangle.landscape.rotate")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.6))
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(.ultraThinMaterial).overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 0.5)))
            }
            .buttonStyle(.plain)

            Button { onStopAll() } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.65))
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.red.opacity(0.2)).overlay(Circle().stroke(Color.red.opacity(0.15), lineWidth: 0.5)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}
