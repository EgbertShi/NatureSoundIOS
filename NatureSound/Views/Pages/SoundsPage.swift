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
    @Binding var showSettings: Bool

    @State private var selectedCategory: SoundCategory = .all
    @State private var showLimitAlert = false

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
                    showSettings: $showSettings,
                    onPlaySounds: { ids in
                        audioManager.stopAll()
                        for id in ids {
                            if let sound = SoundItem.allSounds.first(where: { $0.id == id }) {
                                audioManager.addSound(sound, volume: 0.7)
                            }
                        }
                    }
                )

                // 今日推荐卡片
                dailyRecommendCard
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

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
    }

    // MARK: - 今日推荐卡片
    private var dailyRecommendCard: some View {
        Button {
            Haptics.medium()
            audioManager.stopAll()
            let scene = dailyRecommendedScene
            for id in scene.soundIDs {
                if let sound = SoundItem.allSounds.first(where: { $0.id == id }) {
                    let vol = scene.volumes[id] ?? 0.7
                    audioManager.addSound(sound, volume: vol)
                }
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(dailyRecommendedScene.color.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: dailyRecommendedScene.icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(dailyRecommendedScene.color)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.gold)
                        Text("今日推荐")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.gold)
                    }
                    Text(dailyRecommendedScene.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.textPrimary(.light))
                    Text(dailyRecommendedScene.description)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textTertiary(.light))
                        .lineLimit(1)
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(dailyRecommendedScene.color)
                        .frame(width: 40, height: 40)
                    Image(systemName: "play.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Theme.cardFill(.light))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Theme.cardBorder(.light), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
            )
        }
        .buttonStyle(.plain)
    }

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
            withAnimation(.spring(response: 0.3)) { audioManager.toggle(sound) }
        } else {
            Haptics.soft()
            showLimitAlert = true
        }
    }
}
