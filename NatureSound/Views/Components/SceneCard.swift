//
//  SceneCard.swift
//  NatureSound
//
//  Created by egbert on 2026/7/1.
//

import SwiftUI

// MARK: - 预设场景卡片
struct SceneCard: View {
    let preset: ScenePreset
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: preset.icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(preset.color)
                    Spacer()
                    Text("\(preset.soundIDs.count) 种声音")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.4))
                }

                Text(preset.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.9))

                Text(preset.description)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.4))
                    .lineLimit(2)

                soundIconStack(soundIDs: preset.soundIDs, maxIcons: 5, iconSize: 22)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(preset.color.opacity(0.2), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 用户场景卡片
struct UserSceneCard: View {
    let scene: UserScene
    let onTap: () -> Void
    let onDelete: () -> Void
    let onRename: () -> Void

    private let cardColor = Color(hex: "FFD54F")

    private var iconSize: CGFloat {
        let count = scene.soundIDs.count
        if count <= 3 { return 24 }
        if count <= 5 { return 20 }
        return 17
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "star.fill")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(cardColor)
                    Spacer()
                    Text("\(scene.soundIDs.count) 种声音")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.4))
                }

                Text(scene.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.9))
                    .lineLimit(1)

                Text("自定义场景")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.4))

                HStack(spacing: 0) {
                    soundIconStack(soundIDs: scene.soundIDs, maxIcons: 7, iconSize: iconSize)
                    Spacer(minLength: 8)
                    Button(action: onRename) {
                        Image(systemName: "pencil")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.white.opacity(0.3))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.white.opacity(0.3))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(cardColor.opacity(0.2), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 共享：声音图标条
private struct soundIconStack: View {
    let soundIDs: [String]
    let maxIcons: Int
    let iconSize: CGFloat

    var body: some View {
        HStack(spacing: -4) {
            ForEach(soundIDs.prefix(maxIcons), id: \.self) { soundID in
                if let sound = SoundItem.allSounds.first(where: { $0.id == soundID }) {
                    ZStack {
                        Circle().fill(sound.color.opacity(0.6)).frame(width: iconSize, height: iconSize)
                        Image(systemName: sound.icon)
                            .font(.system(size: iconSize * 0.4))
                            .foregroundStyle(.white)
                    }
                    .overlay(Circle().stroke(Color(hex: "1A1A2E"), lineWidth: 1.5))
                }
            }
        }
    }
}
