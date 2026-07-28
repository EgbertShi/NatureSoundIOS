//
//  AmbianceCard.swift
//  NatureSound
//
//  Created by egbert on 2026/7/1.
//

import SwiftUI

// MARK: - 沉浸式顶部氛围 Header
// 展示应用标题、播放状态、天气问候、时段文案与今日推荐场景，作为"声音"tab 的沉浸式头图。
// 底部内容区整合了原"推荐声音行"与"今日推荐卡片"两个功能，统一为一键播放入口。
// 当当前播放的声音组合命中某个预设场景且有视频/缩略图资源时，自动切换为场景预览图/视频背景。
struct AmbianceCard: View {
    let audioManager: AudioManager
    let timerManager: TimerManager
    let weatherService: WeatherService
    let videoManager: VideoManager
    let recommendation: DailyRecommendation
    @Binding var showSettings: Bool
    /// 播放指定场景（含各声音独立音量）
    let onPlayScene: (ScenePreset) -> Void
    /// 播放指定单个声音
    let onPlaySound: (SoundItem) -> Void

    // MARK: - 与 StandbyView 共享的沉浸模式选择（@AppStorage）
    // 确保首页卡片视频与沉浸模式场景视频使用同一场景、同一变体，保持两端同步。
    @AppStorage("standby_selectedSceneID") private var standbySceneID: String?
    @AppStorage("standby_selectedVideoVariant") private var standbyVideoVariant = 0

    /// 当前场景应使用的视频变体索引。
    /// 仅当 AmbianceCard 展示的场景与沉浸模式中选择的场景一致时，才使用持久化的变体；
    /// 否则回退到 0（默认变体）。
    private var currentVideoVariant: Int {
        guard let sceneID = matchedScene?.id, sceneID == standbySceneID else { return 0 }
        let maxIdx = videoManager.videoVariantCount(for: sceneID) - 1
        return maxIdx >= 0 ? min(standbyVideoVariant, maxIdx) : 0
    }

    private var period: DayPeriod { .current() }
    private var weather: WeatherCondition? { weatherService.currentWeather }

    /// 根据当前时段和天气选取的背景图片名称（稳定值，视图存续期间不随机变化）
    @State private var currentImageName = DayPeriod.current().ambianceImageName(weather: nil)

    /// 当前播放声音匹配到的预设场景（仅当场景有视频/缩略图资源时返回）
    /// 优先使用 AudioManager 记录的当前场景（由场景页 applyPreset 或推荐播放设置），
    /// 确保 AmbianceCard 视频与用户选择的场景同步；currentSceneID 为空时回退到声音 ID 匹配。
    private var matchedScene: ScenePreset? {
        guard audioManager.activeCount > 0 else { return nil }
        // 优先跟随用户明确选择的场景
        if let currentID = audioManager.currentSceneID,
           let scene = ScenePreset.allPresets.first(where: { $0.id == currentID }),
           videoManager.hasAsset(for: scene.id) {
            return scene
        }
        // 回退：根据活跃声音匹配最佳场景
        let activeIDs = Set(audioManager.activePlayers.map { $0.sound.id })
        guard let scene = ScenePreset.bestMatch(for: activeIDs) else { return nil }
        guard videoManager.hasAsset(for: scene.id) else { return nil }
        return scene
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // 背景层：命中场景时显示场景预览图/视频，否则显示天气氛围图
            if let scene = matchedScene {
                sceneBackground(for: scene)
            } else {
                backgroundLayer
            }

            VStack(alignment: .leading, spacing: 0) {
                topBar

                Spacer()

                if let scene = matchedScene {
                    // MARK: 场景匹配内容
                    sceneContent(for: scene)
                } else {
                    // MARK: 天气问候 + 今日推荐
                    weatherRow
                        .padding(.horizontal, 20)
                        .padding(.top, 14)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(period.greeting(weather: weather))
                            .font(.system(size: 26, weight: .bold))
                            .contentTransition(.numericText())
                        Text(period.subtitle(weather: weather))
                            .font(.system(size: 14))
                            .foregroundStyle(Color.white.opacity(0.75))
                            .contentTransition(.numericText())
                    }
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)

                    // 今日推荐行（场景或氛围声音）
                    recommendationRow
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 22)
                }
            }
        }
        .frame(height: 360)
        .clipShape(RoundedRectangle(cornerRadius: 0))
        .animation(.easeInOut(duration: 0.5), value: weather)
        .animation(.easeInOut(duration: 0.4), value: matchedScene?.id)
        .animation(.easeInOut(duration: 0.4), value: currentVideoVariant)
        .onAppear { refreshImageName() }
        .onChange(of: weatherService.currentWeather) { _, _ in refreshImageName() }
        // 命中场景时异步缓存缩略图和视频（使用与沉浸模式一致的变体）
        .task(id: "\(matchedScene?.id ?? "")_\(currentVideoVariant)") {
            guard let scene = matchedScene else { return }
            let variant = currentVideoVariant
            await videoManager.cacheThumbnail(for: scene.id, variantIndex: variant)
            guard !Task.isCancelled else { return }
            await videoManager.cacheAsset(for: scene.id, variantIndex: variant)
        }
    }

    /// 更新背景图片名称，仅在 onAppear 或天气变化时调用
    private func refreshImageName() {
        currentImageName = period.ambianceImageName(weather: weather)
    }

    // MARK: - 今日推荐行（场景或氛围声音）

    @ViewBuilder
    private var recommendationRow: some View {
        switch recommendation {
        case .scene(let preset):
            recommendedSceneRow(preset)
        case .sound(let sound):
            recommendedSoundRow(sound)
        }
    }

    private func recommendedSceneRow(_ preset: ScenePreset) -> some View {
        Button {
            Haptics.medium()
            onPlayScene(preset)
        } label: {
            HStack(spacing: 12) {
                // 场景图标
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 38, height: 38)
                    Image(systemName: preset.icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.white)
                }

                // 场景名称 + 声音图标
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 9))
                            .foregroundStyle(Color(hex: "FFD54F"))
                        Text("今日推荐")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color(hex: "FFD54F"))
                        Text("·")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.white.opacity(0.5))
                        Text(preset.name)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.white)
                    }

                    // 声音图标条
                    HStack(spacing: -3) {
                        ForEach(preset.soundIDs.prefix(5), id: \.self) { soundID in
                            if let sound = SoundItem.allSounds.first(where: { $0.id == soundID }) {
                                ZStack {
                                    Circle()
                                        .fill(sound.color.opacity(0.7))
                                        .frame(width: 18, height: 18)
                                    Image(systemName: sound.icon)
                                        .font(.system(size: 8))
                                        .foregroundStyle(.white)
                                }
                                .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))
                            }
                        }
                        if preset.soundIDs.count > 5 {
                            Text("+\(preset.soundIDs.count - 5)")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.6))
                                .padding(.leading, 4)
                        }
                    }
                }

                Spacer()

                // 播放按钮
                HStack(spacing: 4) {
                    Image(systemName: "play.fill").font(.system(size: 11))
                    Text("播放").font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(Color.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.white.opacity(0.2)))
                .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1))
            }
        }
        .buttonStyle(.plain)
    }

    private func recommendedSoundRow(_ sound: SoundItem) -> some View {
        Button {
            Haptics.medium()
            onPlaySound(sound)
        } label: {
            HStack(spacing: 12) {
                // 声音图标
                ZStack {
                    Circle()
                        .fill(sound.color.opacity(0.5))
                        .frame(width: 38, height: 38)
                    Image(systemName: sound.icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.white)
                }

                // 声音名称 + 描述
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 9))
                            .foregroundStyle(Color(hex: "FFD54F"))
                        Text("今日推荐")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color(hex: "FFD54F"))
                        Text("·")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.white.opacity(0.5))
                        Text(sound.name)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.white)
                    }

                    Text(sound.description)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.65))
                        .lineLimit(1)
                }

                Spacer()

                // 播放按钮
                HStack(spacing: 4) {
                    Image(systemName: audioManager.isPlaying(sound) ? "checkmark" : "play.fill")
                        .font(.system(size: 11))
                    Text(audioManager.isPlaying(sound) ? "播放中" : "播放")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(Color.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(audioManager.isPlaying(sound) ? Color.white.opacity(0.35) : Color.white.opacity(0.2)))
                .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1))
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - 场景匹配背景（视频/缩略图/渐变）

    @ViewBuilder
    private func sceneBackground(for scene: ScenePreset) -> some View {
        let variant = currentVideoVariant
        ZStack {
            if let videoURL = videoManager.cachedVideoURL(for: scene.id, variantIndex: variant) {
                LoopingVideoPlayer(
                    url: videoURL,
                    isActive: true,
                    previewImage: videoManager.cachedThumbnailImage(for: scene.id, variantIndex: variant)
                )
                // 场景切换时强制重建 UIView，确保旧场景的 AVPlayerLayer 被完全移除（dismantleUIView → cleanup），
                // 避免复用同一 UIView 时旧视频画面残留与新场景画面同时出现。
                .id(scene.id)
            } else if let thumbnail = videoManager.cachedThumbnailImage(for: scene.id, variantIndex: variant) {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 360)
                    .clipped()
            } else {
                // 无缩略图时使用当前时段氛围图兜底，叠加场景主题色遮罩
                Image(currentImageName.isEmpty ? DayPeriod.current().ambianceImageName : currentImageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 360)
                    .clipped()
                    .overlay(scene.color.opacity(0.25))
            }

            darkenOverlay
        }
    }

    // MARK: - 场景匹配内容（标签 + 名称 + 描述 + 声音图标）

    @ViewBuilder
    private func sceneContent(for scene: ScenePreset) -> some View {
        HStack(spacing: 6) {
            ForEach(scene.tags.prefix(2), id: \.self) { tag in
                Text(tag.rawValue)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.white.opacity(0.25)))
            }
            Spacer()
            Text("\(scene.soundIDs.count) 种声音")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.7))
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)

        VStack(alignment: .leading, spacing: 6) {
            Text(scene.name)
                .font(.system(size: 26, weight: .bold))
                .contentTransition(.numericText())
            Text(scene.description)
                .font(.system(size: 14))
                .foregroundStyle(Color.white.opacity(0.75))
                .contentTransition(.numericText())
        }
        .foregroundStyle(Color.white)
        .padding(.horizontal, 20)
        .padding(.top, 10)

        HStack {
            soundIconStack(soundIDs: scene.soundIDs, maxIcons: 7, iconSize: 24)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 22)
    }

    // MARK: - 背景层（真实图片 + 渐变叠加）

    private var backgroundLayer: some View {
        ZStack {
            if !currentImageName.isEmpty {
                Image(currentImageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 360)
                    .clipped()
            } else {
                Color(hex: "1C2833")
            }

            darkenOverlay
        }
    }

    // MARK: - 共享遮罩渐变

    private var darkenOverlay: some View {
        ZStack {
            // 顶部暗角渐变，保证标题栏可读性
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [Color.black.opacity(0.45), Color.black.opacity(0.1), .clear],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 120)
                Spacer()
            }

            // 底部暗角渐变，保证文案可读性
            VStack(spacing: 0) {
                Spacer()
                LinearGradient(
                    colors: [.clear, Color.black.opacity(0.15), Color.black.opacity(0.55)],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 200)
            }
        }
    }

    // MARK: - 天气信息行

    private var weatherRow: some View {
        Group {
            if let weather {
                HStack(spacing: 0) {
                    Image(systemName: weather.icon)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.9))

                    Text(weather.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.95))
                        .padding(.leading, 5)

                    if let temp = weatherService.temperature {
                        Text("\(Int(temp))°")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.white)
                            .padding(.leading, 6)
                    }

                    Text("·")
                        .foregroundStyle(Color.white.opacity(0.5))
                        .padding(.horizontal, 6)
                    Text(weather.feelsDescription)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.7))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.black.opacity(0.25)))
                .transition(.opacity)
            } else {
                HStack(spacing: 6) {
                    Image(systemName: periodIcon)
                        .font(.system(size: 13))
                    Text(periodLabel)
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(Color.white.opacity(0.85))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.black.opacity(0.2)))
            }
        }
    }

    // MARK: - 顶部标题栏

    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("清籁")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                if let scene = matchedScene {
                    Text("正在播放：\(scene.name)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.7))
                } else {
                    Text(audioManager.activeCount > 0 ? "正在播放 \(audioManager.activeCount) 种声音" : "点击声音卡片开始聆听")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.7))
                }
            }
            .foregroundStyle(Color.white)

            Spacer()

            if timerManager.isActive {
                HStack(spacing: 4) {
                    Image(systemName: "timer").font(.system(size: 11))
                    Text(timerManager.displayTime).font(.system(size: 12, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(Color(hex: "FFB4A8"))
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Capsule().fill(Color.white.opacity(0.15)))
            }

            Button {
                Haptics.light()
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.white.opacity(0.15)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 54)
    }

    // MARK: - 辅助方法

    private var periodIcon: String {
        switch period {
        case .morning:   return "sunrise.fill"
        case .afternoon: return "sun.max.fill"
        case .evening:   return "sunset.fill"
        case .night:     return "moon.stars.fill"
        }
    }

    private var periodLabel: String {
        switch period {
        case .morning:   return "清晨"
        case .afternoon: return "午后"
        case .evening:   return "傍晚"
        case .night:     return "夜晚"
        }
    }
}
