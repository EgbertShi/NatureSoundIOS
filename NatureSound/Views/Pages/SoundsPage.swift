//
//  SoundsPage.swift
//  NatureSound
//
//  Created by egbert on 2026/7/1.
//

import SwiftUI

// MARK: - 声音页面
struct SoundsPage: View {
    let audioManager: AudioManager
    let timerManager: TimerManager
    let weatherService: WeatherService
    let videoManager: VideoManager
    @Binding var showSettings: Bool

    @State private var selectedCategory: SoundCategory = .all
    @State private var showLimitAlert = false
    @State private var showPlaybackFailedAlert = false

    private var columns: [GridItem] { [GridItem(.adaptive(minimum: 100), spacing: 12)] }
    private var filteredSounds: [SoundItem] { SoundItem.sounds(for: selectedCategory) }

    /// 今日推荐场景（根据时段选择）
    private var dailyRecommendedScene: ScenePreset {
        let sceneID: String
        switch DayPeriod.current() {
        case .morning: sceneID = "spring_garden"
        case .afternoon: sceneID = "deep_focus"
        case .evening: sceneID = "zen_temple"
        case .night: sceneID = "ocean_night"
        }

        if let scene = ScenePreset.allPresets.first(where: { $0.id == sceneID }) ?? ScenePreset.allPresets.first {
            return scene
        }
        fatalError("scenes.json 未包含可用场景")
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                AmbianceCard(
                    audioManager: audioManager,
                    timerManager: timerManager,
                    weatherService: weatherService,
                    videoManager: videoManager,
                    recommendedScene: dailyRecommendedScene,
                    showSettings: $showSettings,
                    onPlayScene: { scene in
                        applyScene(scene)
                    }
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
                .padding(.horizontal, 20)
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
                    .foregroundStyle(Theme.textSecondary(.light))
                Text("·").foregroundStyle(Theme.textTertiary(.light))
                Text("还可添加 \(remaining) 种")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(remaining <= 2 ? Theme.danger.opacity(0.8) : Theme.textTertiary(.light))
            } else {
                Image(systemName: "hand.tap")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary(.light))
                Text("点击声音卡片开始叠加播放")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textTertiary(.light))
            }
            Spacer()
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
