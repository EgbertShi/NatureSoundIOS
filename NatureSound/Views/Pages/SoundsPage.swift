//
//  SoundsPage.swift
//  NatureSound
//
//  Created by egbert on 2026/7/1.
//

import SwiftUI

// MARK: - 每日推荐类型
enum DailyRecommendation {
    /// 推荐一个场景（包含多种声音的组合）
    case scene(ScenePreset)
    /// 推荐一个氛围声音（单个声音）
    case sound(SoundItem)

    /// 用于标识推荐内容是否变化的 key
    var id: String {
        switch self {
        case .scene(let preset): return "scene_\(preset.id)"
        case .sound(let item):   return "sound_\(item.id)"
        }
    }

    /// 基于日期和时段生成今日推荐：从所有场景和氛围声音中选取。
    /// 使用日期+时段作为伪随机种子，保证同一时段内推荐内容稳定。
    static func today() -> DailyRecommendation {
        let calendar = Calendar.current
        let now = Date()
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: now) ?? 1
        let period = DayPeriod.current()
        let periodOffset: Int = switch period {
        case .morning:   0
        case .afternoon: 1
        case .evening:   2
        case .night:     3
        }
        let seed = dayOfYear * 4 + periodOffset

        // 候选池：所有场景 + 氛围分类下的所有声音
        let scenes = ScenePreset.allPresets
        let ambientSounds = SoundItem.allSounds.filter { $0.category == .ambient }
        let totalCount = scenes.count + ambientSounds.count
        guard totalCount > 0 else {
            return .scene(scenes.first ?? ScenePreset.allPresets[0])
        }

        let index = seed % totalCount
        if index < scenes.count {
            return .scene(scenes[index])
        } else {
            return .sound(ambientSounds[index - scenes.count])
        }
    }
}

// MARK: - 声音页面
struct SoundsPage: View {
    let audioManager: AudioManager
    let timerManager: TimerManager
    let weatherService: WeatherService
    let videoManager: VideoManager
    @Binding var showSettings: Bool
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var selectedCategory: SoundCategory = .all
    @State private var showLimitAlert = false
    @State private var showPlaybackFailedAlert = false

    private var columns: [GridItem] {
        let minWidth: CGFloat = sizeClass == .regular ? 120 : 100
        return [GridItem(.adaptive(minimum: minWidth), spacing: sizeClass == .regular ? 16 : 12)]
    }
    private var filteredSounds: [SoundItem] { SoundItem.sounds(for: selectedCategory) }

    /// 今日推荐（场景或氛围声音，每个时段切换一次）
    private var dailyRecommendation: DailyRecommendation { .today() }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                AmbianceCard(
                    audioManager: audioManager,
                    timerManager: timerManager,
                    weatherService: weatherService,
                    videoManager: videoManager,
                    recommendation: dailyRecommendation,
                    showSettings: $showSettings,
                    onPlayScene: { scene in
                        applyScene(scene)
                    },
                    onPlaySound: { sound in
                        playRecommendedSound(sound)
                    },
                    cardHeight: sizeClass == .regular ? 420 : 360
                )

                CategoryTabView(selectedCategory: $selectedCategory)
                    .padding(.top, 12)

                activeCountBadge
                    .padding(.top, 12)
                    .padding(.horizontal, 20)

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(filteredSounds) { sound in
                        SoundCardView(
                            sound: sound,
                            isActive: audioManager.isPlaying(sound),
                            isDisabled: !audioManager.canAddMore && !audioManager.isPlaying(sound)
                        ) { handleSoundTap(sound) }
                    }
                }
                .padding(.horizontal, sizeClass == .regular ? 28 : 20)
                .padding(.top, 8)
                .padding(.bottom, audioManager.activeCount > 0 ? 160 : 40)
            }
        }
        .ignoresSafeArea(edges: .top)
        .alert("已达叠加上限", isPresented: $showLimitAlert) {
            Button("我知道了", role: .cancel) {}
        } message: {
            Text("最多同时叠加 \(AudioManager.maxConcurrentSounds) 种声音，请先关闭部分声音后再添加新的声音。")
        }
        .alert("播放失败", isPresented: $showPlaybackFailedAlert) {
            Button("我知道了", role: .cancel) {}
        } message: {
            Text("该声音暂时无法播放，请稍后重试。")
        }
    }

    // MARK: - 播放场景

    private func applyScene(_ scene: ScenePreset) {
        withAnimation(.spring(response: 0.4)) {
            ScenePlaybackCoordinator(audioManager: audioManager, videoManager: videoManager).apply(scene)
        }
    }

    // MARK: - 已选计数

    private var activeCountBadge: some View {
        HStack(spacing: 6) {
            let remaining = AudioManager.maxConcurrentSounds - audioManager.activeCount

            if audioManager.activeCount > 0 {
                Image(systemName: "waveform")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.accent)
                Text("已选 \(audioManager.activeCount) 种")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textSecondary(colorScheme))
                Text("·").foregroundStyle(Theme.textTertiary(colorScheme))
                Text("还可添加 \(remaining) 种")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(remaining <= 2 ? Theme.danger.opacity(0.8) : Theme.textTertiary(colorScheme))
            } else {
                Image(systemName: "hand.tap")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary(colorScheme))
                Text("点击声音卡片开始叠加播放")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textTertiary(colorScheme))
            }
            Spacer()
        }
    }

    // MARK: - 播放推荐声音

    private func playRecommendedSound(_ sound: SoundItem) {
        if audioManager.isPlaying(sound) { return }
        if audioManager.canAddMore {
            Haptics.medium()
            var succeeded = true
            withAnimation(.spring(response: 0.3)) { succeeded = audioManager.toggle(sound) }
            if !succeeded {
                Haptics.soft()
                showPlaybackFailedAlert = true
            }
        } else {
            Haptics.soft()
            showLimitAlert = true
        }
    }

    private func handleSoundTap(_ sound: SoundItem) {
        if audioManager.isPlaying(sound) {
            Haptics.light()
            withAnimation(.spring(response: 0.3)) { audioManager.toggle(sound) }
        } else if audioManager.canAddMore {
            Haptics.medium()
            var succeeded = true
            withAnimation(.spring(response: 0.3)) { succeeded = audioManager.toggle(sound) }
            if !succeeded {
                Haptics.soft()
                showPlaybackFailedAlert = true
            }
        } else {
            Haptics.soft()
            showLimitAlert = true
        }
    }
}
