//
//  SoundCardView.swift
//  NatureSound
//
//  Created by egbert on 2026/7/1.
//

import SwiftUI

// MARK: - 声音卡片视图
struct SoundCardView: View {
    let sound: SoundItem
    let isActive: Bool
    let isDisabled: Bool
    let onTap: () -> Void

    @State private var isPressed = false
    @State private var pulseAnimation = false

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 10) {
                ZStack {
                    if isActive {
                        Circle()
                            .fill(sound.color.opacity(0.3))
                            .frame(width: 56, height: 56)
                            .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                            .opacity(pulseAnimation ? 0.3 : 0.6)
                    }
                    Circle()
                        .fill(isActive ? sound.color.opacity(0.25) : Color.white.opacity(0.06))
                        .frame(width: 48, height: 48)
                    Image(systemName: sound.icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(isActive ? sound.color : Color.white.opacity(0.5))
                        .symbolEffect(.bounce, value: isActive)
                }
                .frame(height: 56)

                Text(sound.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isActive ? sound.color : Color.white.opacity(isDisabled ? 0.3 : 0.6))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isActive ? sound.color.opacity(0.1) : Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isActive ? sound.color.opacity(0.4) : Color.white.opacity(0.06), lineWidth: 1)
                    )
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .opacity(isDisabled ? 0.5 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.15)) { isPressed = pressing }
        }, perform: {})
        .onChange(of: isActive) { _, newValue in
            if newValue {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) { pulseAnimation = true }
            } else { pulseAnimation = false }
        }
        .onAppear {
            if isActive {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) { pulseAnimation = true }
            }
        }
    }
}

// MARK: - 已选声音控制条
struct ActiveSoundRow: View {
    let player: SoundPlayer
    let onRemove: () -> Void

    @State private var localVolume: Float

    init(player: SoundPlayer, onRemove: @escaping () -> Void) {
        self.player = player
        self.onRemove = onRemove
        self._localVolume = State(initialValue: player.volume)
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(player.sound.color.opacity(0.2)).frame(width: 36, height: 36)
                Image(systemName: player.sound.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(player.sound.color)
            }

            Text(player.sound.name)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.85))
                .frame(width: 60, alignment: .leading)

            Slider(value: Binding(
                get: { localVolume },
                set: { newValue in
                    localVolume = newValue
                    player.volume = newValue
                    player.updateVolume(newValue)
                }
            ), in: 0...1)
            .tint(player.sound.color)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.white.opacity(0.4))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}
