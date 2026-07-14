//
//  StandbyControls.swift
//  NatureSound
//
//  Created by egbert on 2026/7/11.
//

import SwiftUI

// MARK: - 声音波形行
struct SoundWaveRow: View {
    let audioManager: AudioManager
    let waveOffset: CGFloat

    var body: some View {
        HStack(spacing: 20) {
            ForEach(Array(audioManager.activePlayers.prefix(7).enumerated()), id: \.offset) { idx, player in
                VStack(spacing: 5) {
                    Image(systemName: player.sound.icon)
                        .font(.system(size: 15))
                        .foregroundStyle(player.sound.color.opacity(0.6))
                    RoundedRectangle(cornerRadius: 1)
                        .fill(player.sound.color.opacity(0.3))
                        .frame(width: 2, height: CGFloat(6 + (idx % 3) * 4))
                        .offset(y: waveOffset * CGFloat((idx % 2 == 0 ? 1 : -1)))
                }
            }
        }
        .padding(.bottom, 2)
        .transition(.opacity)
    }
}

// MARK: - 迷你混音器
struct StandbyMixer: View {
    let audioManager: AudioManager
    let onVolumeChange: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("混音器").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.white.opacity(0.5))
                Spacer()
                Text("\(audioManager.activeCount) 种声音").font(.system(size: 11)).foregroundStyle(Color.white.opacity(0.3))
            }
            VStack(spacing: 10) {
                ForEach(audioManager.activePlayers) { player in
                    HStack(spacing: 12) {
                        Circle().fill(player.sound.color.opacity(0.6)).frame(width: 8, height: 8)
                        Text(player.sound.name).font(.system(size: 12, weight: .medium)).foregroundStyle(Color.white.opacity(0.6)).lineLimit(1)
                        Spacer()
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
                        .frame(width: 90)
                        Text("\(Int(player.volume * 100))")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.3))
                            .frame(width: 26, alignment: .trailing)
                    }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
        )
    }
}

// MARK: - 主控制面板（音量 + 亮度）
struct StandbyControlPanel: View {
    @Binding var masterVolume: Float
    @Binding var brightness: Double
    let audioManager: AudioManager
    let onInteract: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            volumeSection
            Divider().background(Color.white.opacity(0.06))
            brightnessSection
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.08), lineWidth: 0.5))
        )
    }

    private var volumeSection: some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: "speaker.wave.1.fill").font(.system(size: 12)).foregroundStyle(Color.white.opacity(0.4))
                Text("音量").font(.system(size: 12, weight: .medium)).foregroundStyle(Color.white.opacity(0.5))
                Spacer()
                Text("\(Int(masterVolume * 100))%").font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(Color.white.opacity(0.4))
            }
            Slider(value: Binding(
                get: { Double(masterVolume) },
                set: { newValue in masterVolume = Float(newValue); audioManager.updateMasterVolume(masterVolume); onInteract() }
            ), in: 0...1)
            .tint(LinearGradient(colors: [Color(hex: "667eea"), Color(hex: "764ba2")], startPoint: .leading, endPoint: .trailing))
        }
    }

    private var brightnessSection: some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: "sun.max.fill").font(.system(size: 12)).foregroundStyle(Color.white.opacity(0.4))
                Text("亮度").font(.system(size: 12, weight: .medium)).foregroundStyle(Color.white.opacity(0.5))
                Spacer()
                Button {
                    Haptics.soft()
                    withAnimation(.easeInOut(duration: 0.4)) { brightness = 0.05; UIScreen.main.brightness = 0.05 }
                    onInteract()
                } label: {
                    Image(systemName: brightness < 0.1 ? "moon.fill" : "moon")
                        .font(.system(size: 12))
                        .foregroundStyle(brightness < 0.1 ? Color(hex: "667eea") : Color.white.opacity(0.4))
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(brightness < 0.1 ? Color(hex: "667eea").opacity(0.15) : Color.white.opacity(0.06)))
                }
                .buttonStyle(.plain)
                Text("\(Int(brightness * 100))%").font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(Color.white.opacity(0.4))
            }
            Slider(value: Binding(
                get: { brightness },
                set: { newValue in brightness = newValue; UIScreen.main.brightness = CGFloat(newValue); onInteract() }
            ), in: 0.05...1)
            .tint(LinearGradient(colors: [Color(hex: "FFD54F"), Color(hex: "FF8E53")], startPoint: .leading, endPoint: .trailing))
        }
    }
}

// MARK: - 工具栏
struct StandbyToolBar: View {
    let showMixer: Bool
    let clockStyle: ClockStyle
    let breathingSpeed: BreathingSpeed
    let autoHide: AutoHideDuration
    let use24Hour: Bool
    let showSeconds: Bool
    let showDate: Bool
    let clockScale: Double

    let onToggleMixer: () -> Void
    let onSelectClockStyle: (ClockStyle) -> Void
    let onToggle24Hour: (Bool) -> Void
    let onToggleSeconds: (Bool) -> Void
    let onToggleDate: (Bool) -> Void
    let onSelectClockScale: (Double) -> Void
    let onSelectBreathingSpeed: (BreathingSpeed) -> Void
    let onSelectAutoHide: (AutoHideDuration) -> Void

    var body: some View {
        HStack(spacing: 0) {
            mixerButton.frame(maxWidth: .infinity)
            clockMenu.frame(maxWidth: .infinity)
            breathingMenu.frame(maxWidth: .infinity)
            autoHideMenu.frame(maxWidth: .infinity)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
        )
    }

    private func toolIcon(_ systemName: String, _ label: String, color: Color? = nil) -> some View {
        VStack(spacing: 3) {
            Image(systemName: systemName).font(.system(size: 15)).foregroundStyle(color ?? Color.white.opacity(0.4))
            Text(label).font(.system(size: 9, weight: .medium)).foregroundStyle(color ?? Color.white.opacity(0.3))
        }
    }

    private var mixerButton: some View {
        Button {
            Haptics.light()
            onToggleMixer()
        } label: {
            toolIcon(showMixer ? "slider.horizontal.3.fill" : "slider.horizontal.3", "混音器", color: showMixer ? Color(hex: "667eea") : nil)
        }
        .buttonStyle(.plain)
    }

    private var clockMenu: some View {
        Menu {
            Section("时钟样式") {
                ForEach(ClockStyle.allCases, id: \.self) { style in
                    Button { Haptics.light(); onSelectClockStyle(style) } label: {
                        if clockStyle == style { Label(style.rawValue, systemImage: "checkmark") }
                        else { Label(style.rawValue, systemImage: style.icon) }
                    }
                }
            }
            Section("显示选项") {
                Toggle("24小时制", isOn: Binding(get: { use24Hour }, set: { onToggle24Hour($0) }))
                Toggle("显示秒", isOn: Binding(get: { showSeconds }, set: { onToggleSeconds($0) }))
                Toggle("显示日期", isOn: Binding(get: { showDate }, set: { onToggleDate($0) }))
            }
            Section("时钟大小") {
                ForEach([("小", 0.8), ("中", 1.0), ("大", 1.3)], id: \.0) { label, scale in
                    Button { Haptics.light(); onSelectClockScale(scale) } label: {
                        if abs(clockScale - scale) < 0.05 { Label(label, systemImage: "checkmark") }
                        else { Text(label) }
                    }
                }
            }
        } label: {
            toolIcon("clock", "时钟")
        }
        .buttonStyle(.plain)
    }

    private var breathingMenu: some View {
        Menu {
            ForEach(BreathingSpeed.allCases, id: \.self) { speed in
                Button { Haptics.light(); onSelectBreathingSpeed(speed) } label: {
                    if breathingSpeed == speed { Label(speed.rawValue, systemImage: "checkmark") }
                    else { Text(speed.rawValue) }
                }
            }
        } label: {
            toolIcon(breathingSpeed == .off ? "circle.dashed" : "waveform.circle", "光晕", color: breathingSpeed == .off ? nil : Color.white.opacity(0.45))
        }
        .buttonStyle(.plain)
    }

    private var autoHideMenu: some View {
        Menu {
            ForEach(AutoHideDuration.allCases, id: \.self) { dur in
                Button { Haptics.light(); onSelectAutoHide(dur) } label: {
                    if autoHide == dur { Label(dur.rawValue, systemImage: "checkmark") }
                    else { Text(dur.rawValue) }
                }
            }
        } label: {
            toolIcon("eye.slash", "隐藏")
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 顶部栏
struct StandbyTopBar: View {
    let mode: StandbyMode
    let timerManager: TimerManager
    let onExit: () -> Void
    let onAddTime: (Int) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button { Haptics.light(); onExit() } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left").font(.system(size: 13, weight: .bold))
                    Text("退出").font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(Color.white.opacity(0.65))
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Capsule().fill(.ultraThinMaterial).overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 0.5)))
            }
            .buttonStyle(.plain)

            Spacer()

            if mode == .timer && timerManager.isActive {
                HStack(spacing: 6) {
                    addButton(5)
                    addButton(10)
                }
                .transition(.scale.combined(with: .opacity))
            }

            Spacer()

            HStack(spacing: 5) {
                Image(systemName: mode == .immersive ? "moon.stars.fill" : "timer").font(.system(size: 11))
                Text(mode == .immersive ? "沉浸" : "定时").font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(Color.white.opacity(0.45))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Capsule().fill(.ultraThinMaterial).overlay(Capsule().stroke(Color.white.opacity(0.06), lineWidth: 0.5)))
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private func addButton(_ minutes: Int) -> some View {
        Button {
            Haptics.medium()
            onAddTime(minutes)
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "plus").font(.system(size: 9, weight: .bold))
                Text("\(minutes)").font(.system(size: 12, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(Color(hex: "FF6B6B"))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule().fill(Color(hex: "FF6B6B").opacity(0.12)).overlay(Capsule().stroke(Color(hex: "FF6B6B").opacity(0.2), lineWidth: 0.5))
            )
        }
        .buttonStyle(.plain)
    }
}
