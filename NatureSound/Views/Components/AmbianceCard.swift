//
//  AmbianceCard.swift
//  NatureSound
//
//  Created by egbert on 2026/7/1.
//

import SwiftUI

// MARK: - 沉浸式顶部氛围 Header
// 展示应用标题、播放状态、天气问候、时段文案与推荐声音，作为"声音"tab 的沉浸式头图
struct AmbianceCard: View {
    let audioManager: AudioManager
    let timerManager: TimerManager
    let weatherService: WeatherService
    @Binding var showSettings: Bool
    let onPlaySounds: ([String]) -> Void

    private var period: DayPeriod { .current() }
    private var weather: WeatherCondition? { weatherService.currentWeather }

    /// 根据当前时段和天气选取的背景图片名称（稳定值，视图存续期间不随机变化）
    @State private var currentImageName = DayPeriod.current().ambianceImageName(weather: nil)

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            backgroundLayer

            VStack(alignment: .leading, spacing: 0) {
                topBar

                Spacer()

                // MARK: 天气信息行
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

                recommendationRow
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 22)
            }
        }
        .frame(height: 360)
        .clipShape(RoundedRectangle(cornerRadius: 0))
        .animation(.easeInOut(duration: 0.5), value: weather)
        .onAppear { refreshImageName() }
        .onChange(of: weatherService.currentWeather) { _, _ in refreshImageName() }
    }

    /// 更新背景图片名称，仅在 onAppear 或天气变化时调用
    private func refreshImageName() {
        currentImageName = period.ambianceImageName(weather: weather)
    }

    // MARK: - 背景层（真实图片 + 渐变叠加）
    private var backgroundLayer: some View {
        ZStack {
            // 底图
            if !currentImageName.isEmpty {
                Image(currentImageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 360)
                    .clipped()
            } else {
                Color(hex: "1C2833")
            }

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
                    // 天气图标
                    Image(systemName: weather.icon)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.9))

                    // 天气类型
                    Text(weather.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.95))
                        .padding(.leading, 5)

                    // 温度
                    if let temp = weatherService.temperature {
                        Text("\(Int(temp))°")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.white)
                            .padding(.leading, 6)
                    }

                    // 分隔符 + 体感文案
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
                // 天气未加载时显示时段信息
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
                Text(audioManager.activeCount > 0 ? "正在播放 \(audioManager.activeCount) 种声音" : "点击声音卡片开始聆听")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.7))
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

    // MARK: - 推荐声音 + 播放按钮
    private var recommendationRow: some View {
        Button {
            let ids = period.recommendedSoundIDs(weather: weather)
            onPlaySounds(ids)
        } label: {
            HStack(spacing: 10) {
                let soundIDs = period.recommendedSoundIDs(weather: weather)
                let sounds = soundIDs.prefix(3).compactMap { id in SoundItem.allSounds.first { $0.id == id } }

                ForEach(sounds, id: \.id) { sound in
                    HStack(spacing: 4) {
                        Image(systemName: sound.icon)
                            .font(.system(size: 10))
                        Text(sound.name)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(Color.white.opacity(0.9))
                }

                Spacer()

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

    // MARK: - 辅助方法

    /// 当前时段对应的 SF Symbol 图标
    private var periodIcon: String {
        switch period {
        case .morning:   return "sunrise.fill"
        case .afternoon: return "sun.max.fill"
        case .evening:   return "sunset.fill"
        case .night:     return "moon.stars.fill"
        }
    }

    /// 当前时段的显示名称
    private var periodLabel: String {
        switch period {
        case .morning:   return "清晨"
        case .afternoon: return "午后"
        case .evening:   return "傍晚"
        case .night:     return "夜晚"
        }
    }
}
