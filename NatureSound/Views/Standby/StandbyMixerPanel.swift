//
//  StandbyMixerPanel.swift
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
