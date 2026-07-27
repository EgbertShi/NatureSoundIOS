//
//  StandbyMasterControlPanel.swift
//  NatureSound
//
//  Created by egbert on 2026/7/11.
//

import SwiftUI

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
