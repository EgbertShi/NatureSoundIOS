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

    @Environment(\.colorScheme) private var colorScheme
    @State private var isPressed = false

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Circle()
                    .fill(isActive ? sound.color.opacity(0.18) : sound.color.opacity(0.12))
                    .frame(width: 46, height: 46)
                    .overlay {
                        Image(systemName: sound.icon)
                            .font(.system(size: 19, weight: .medium))
                            .foregroundStyle(sound.color)
                    }

                Text(sound.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isActive ? sound.color : Theme.textPrimary(colorScheme).opacity(isDisabled ? 0.5 : 1))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 88)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isActive ? sound.color.opacity(0.08) : Theme.cardFill(colorScheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(isActive ? sound.color.opacity(0.26) : .clear, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(isActive ? 0.02 : 0.06), radius: 7, y: 3)
            )
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .opacity(isDisabled ? 0.5 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.15)) { isPressed = pressing }
        }, perform: {})
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
