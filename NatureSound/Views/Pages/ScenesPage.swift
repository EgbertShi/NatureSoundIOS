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
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var sizeClass

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
                    .foregroundStyle(Theme.textPrimary(colorScheme))
                Text("聆听自然 · 疗愈心灵")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textTertiary(colorScheme))
            }
            Spacer()
            Button {
                Haptics.light()
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.iconDefault(colorScheme))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Theme.inactiveFill(colorScheme)))
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
                .foregroundStyle(Theme.textPrimary(colorScheme))
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
                .foregroundStyle(Theme.textPrimary(colorScheme))
                .padding(.horizontal, 20)

            tagFilterRow

            LazyVGrid(columns: [GridItem(.adaptive(minimum: sizeClass == .regular ? 200 : 160), spacing: sizeClass == .regular ? 16 : 12)], spacing: sizeClass == .regular ? 16 : 12) {
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
                    .fill(isSelected ? Theme.accent : Theme.inactiveFill(colorScheme))
            )
            .foregroundStyle(isSelected ? Color.white : Theme.textSecondary(colorScheme))
        }
        .buttonStyle(.plain)
    }

    private func applyPreset(_ preset: ScenePreset) {
        Haptics.medium()
        withAnimation(.spring(response: 0.4)) {
            ScenePlaybackCoordinator(audioManager: audioManager, videoManager: videoManager).apply(preset)
        }
    }
}
