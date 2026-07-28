//
//  SceneCard.swift
//  NatureSound
//
//  Created by egbert on 2026/7/1.
//

import SwiftUI

// MARK: - 精选场景卡片（带视频缩略图背景）
struct FeaturedSceneCard: View {
    let preset: ScenePreset
    let videoManager: VideoManager
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomLeading) {
                // 背景缩略图；无缩略图时使用当前时段氛围图兜底
                if let image = videoManager.cachedThumbnailImage(for: preset.id, variantIndex: 0) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .clipped()
                } else {
                    fallbackBackground
                }

                // 全屏渐变遮罩，保证文字可读性
                LinearGradient(
                    colors: [Color.black.opacity(0.15), .clear, Color.black.opacity(0.7)],
                    startPoint: .top, endPoint: .bottom
                )

                // 顶部标签行
                VStack(alignment: .leading) {
                    HStack(spacing: 6) {
                        ForEach(preset.tags.prefix(2), id: \.self) { tag in
                            Text(tag.rawValue)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Color.white.opacity(0.25)))
                        }
                        Spacer()
                        Text("\(preset.soundIDs.count) 种声音")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.7))
                    }

                    Spacer()

                    // 底部信息
                    VStack(alignment: .leading, spacing: 5) {
                        Text(preset.name)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)

                        Text(preset.description)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.white.opacity(0.7))
                            .lineLimit(1)

                        soundIconStack(soundIDs: preset.soundIDs, maxIcons: 5, iconSize: 20)
                    }
                }
                .padding(12)
            }
            .frame(width: 250, height: 148)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
        .task(id: preset.id) {
            // VideoManager 现已标记为 @Observable，缓存写入成功后会自动驱动本视图重新求值，
            // 无需再依赖本地额外的 dirty-flag 状态。
            await videoManager.cacheThumbnail(for: preset.id)
        }
    }

    /// 缩略图未加载时的兜底背景：使用当前时段的氛围图片，
    /// 与首页 AmbianceCard 的背景保持视觉一致。
    private var fallbackBackground: some View {
        Image(DayPeriod.current().ambianceImageName)
            .resizable()
            .scaledToFill()
            .overlay(
                // 叠加场景主题色遮罩，保留场景辨识度
                preset.color.opacity(0.3)
            )
    }
}

// MARK: - 预设场景卡片
struct SceneCard: View {
    let preset: ScenePreset
    let onTap: () -> Void

    @Environment(\.colorScheme) private var colorScheme

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
                        .foregroundStyle(Theme.textTertiary(colorScheme))
                }

                Text(preset.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary(colorScheme))

                Text(preset.description)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary(colorScheme))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 30, alignment: .top)

                soundIconStack(soundIDs: preset.soundIDs, maxIcons: 5, iconSize: 20, borderColor: Theme.cardBorder(colorScheme))
            }
            .padding(14)
            .frame(minHeight: 152)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.cardFill(colorScheme))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.cardBorder(colorScheme), lineWidth: 1))
                    .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
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

    @Environment(\.colorScheme) private var colorScheme

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
                        .foregroundStyle(Theme.textTertiary(colorScheme))
                }

                Text(scene.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary(colorScheme))
                    .lineLimit(1)

                Text("自定义场景")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary(colorScheme))

                HStack(spacing: 0) {
                    soundIconStack(soundIDs: scene.soundIDs, maxIcons: 7, iconSize: iconSize, borderColor: Theme.cardBorder(colorScheme))
                    Spacer(minLength: 8)
                    Button(action: onRename) {
                        Image(systemName: "pencil")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textTertiary(colorScheme))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textTertiary(colorScheme))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
            .frame(minHeight: 152)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.cardFill(colorScheme))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(cardColor.opacity(0.2), lineWidth: 1))
                    .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 共享：声音图标条
struct soundIconStack: View {
    let soundIDs: [String]
    let maxIcons: Int
    let iconSize: CGFloat
    var borderColor: Color = .white

    var body: some View {
        HStack(spacing: -4) {
            ForEach(soundIDs.prefix(maxIcons), id: \.self) { soundID in
                if let sound = SoundItem.allSounds.first(where: { $0.id == soundID }) {
                    ZStack {
                        Circle().fill(sound.color.opacity(0.6)).frame(width: iconSize, height: iconSize)
                        Image(systemName: sound.icon)
                            .font(.system(size: iconSize * 0.45))
                            .foregroundStyle(.white)
                    }
                    .overlay(Circle().stroke(borderColor, lineWidth: 1.5))
                }
            }
        }
    }
}
