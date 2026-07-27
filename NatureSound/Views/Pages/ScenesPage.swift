//
//  ScenesPage.swift
//  NatureSound
//
//  Created by egbert on 2026/7/1.
//

import SwiftUI

// MARK: - 场景页面
struct ScenesPage: View {
    let audioManager: AudioManager
    let sceneManager: SceneManager
    let videoManager: VideoManager
    @Binding var showSettings: Bool

    @State private var selectedTag: SceneTag?

    private var filteredPresets: [ScenePreset] {
        guard let selectedTag else { return ScenePreset.allPresets }
        return ScenePreset.allPresets.filter { $0.tags.contains(selectedTag) }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                pageHeader
                featuredSection
                moreScenesSection
            }
            .padding(.top, 54)
            .padding(.bottom, audioManager.activeCount > 0 ? 160 : 40)
        }
        .ignoresSafeArea(edges: .top)
    }

    // MARK: - 页面标题栏
    private var pageHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("清籁")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary(.light))
                Text("聆听自然 · 疗愈心灵")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textTertiary(.light))
            }
            Spacer()
            Button {
                Haptics.light()
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.iconDefault(.light))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Theme.inactiveFill(.light)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - 精选场景
    private var featuredSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("精选场景")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.textPrimary(.light))
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(ScenePreset.featuredPresets) { preset in
                        FeaturedSceneCard(preset: preset, videoManager: videoManager) { applyPreset(preset) }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - 更多场景
    private var moreScenesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("更多场景")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.textPrimary(.light))
                .padding(.horizontal, 20)

            tagFilterRow

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
                ForEach(filteredPresets) { preset in
                    SceneCard(preset: preset) { applyPreset(preset) }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private var tagFilterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                tagChip(title: "全部", icon: "square.grid.2x2.fill", isSelected: selectedTag == nil) {
                    selectedTag = nil
                }
                ForEach(SceneTag.allCases) { tag in
                    tagChip(title: tag.rawValue, icon: tag.icon, isSelected: selectedTag == tag) {
                        selectedTag = (selectedTag == tag) ? nil : tag
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func tagChip(title: String, icon: String, isSelected: Bool, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 11, weight: .medium))
                Text(title).font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Theme.accent : Theme.inactiveFill(.light))
            )
            .foregroundStyle(isSelected ? Color.white : Theme.textSecondary(.light))
        }
        .buttonStyle(.plain)
    }

    private func applyPreset(_ preset: ScenePreset) {
        Haptics.medium()
        withAnimation(.spring(response: 0.4)) {
            audioManager.stopAll()
            for soundID in preset.soundIDs {
                if let sound = SoundItem.allSounds.first(where: { $0.id == soundID }) {
                    audioManager.addSound(sound, volume: preset.volumes[soundID] ?? 0.7)
                }
            }
        }
        // 设置场景信息，用于锁屏 Now Playing 封面展示
        let artwork = videoManager.nowPlayingArtwork(for: preset.id)
        audioManager.setCurrentScene(id: preset.id, name: preset.name, artwork: artwork)
        // 如果本地没有缩略图缓存，异步下载后更新
        if artwork == nil {
            Task {
                if let image = await videoManager.fetchNowPlayingArtwork(for: preset.id) {
                    await MainActor.run {
                        audioManager.setCurrentScene(id: preset.id, name: preset.name, artwork: image)
                    }
                }
            }
        }
    }
}
