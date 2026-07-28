//
//  WelcomeView.swift
//  NatureSound
//
//  Created by egbert on 2026/7/1.
//

import SwiftUI

// MARK: - 首次目标

private enum WelcomeIntent: String, CaseIterable, Identifiable {
    case sleep = "更快入睡"
    case focus = "安静专注"
    case relax = "放松一下"
    case maskNoise = "遮盖噪声"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .sleep: return "moon.stars.fill"
        case .focus: return "brain.head.profile.fill"
        case .relax: return "leaf.fill"
        case .maskNoise: return "speaker.wave.3.fill"
        }
    }

    var subtitle: String {
        switch self {
        case .sleep: return "低变化的自然背景，陪你慢慢安静下来"
        case .focus: return "稳定的环境声，减少外界干扰"
        case .relax: return "给自己留一段呼吸与放松的时间"
        case .maskNoise: return "用持续自然声柔化周围杂音"
        }
    }

    var color: Color {
        switch self {
        case .sleep: return Color(hex: "7C83FD")
        case .focus: return Color(hex: "4F9DDE")
        case .relax: return Color(hex: "52B788")
        case .maskNoise: return Color(hex: "F4A261")
        }
    }

    /// 每个目标挑选一套稳定、低门槛的预设；缺失时安全回退到首个场景。
    var preferredSceneID: String {
        switch self {
        case .sleep: return "ocean_night"
        case .focus: return "deep_focus"
        case .relax: return "forest_meditation"
        case .maskNoise: return "rainy_reading"
        }
    }
}

// MARK: - 目标导向欢迎页

struct WelcomeView: View {
    let audioManager: AudioManager
    let videoManager: VideoManager
    @Binding var hasSeenWelcome: Bool

    @State private var opacity: Double = 0
    @State private var selectedIntent: WelcomeIntent?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "0F0C29"), Color(hex: "1A1A2E"), Color(hex: "16213E")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer(minLength: 80)

                    Text("清籁")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("此刻，你想让自己更接近哪种状态？")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white.opacity(0.92))
                        .padding(.top, 24)

                    Text("选一个目标，我们会立刻为你准备好合适的自然声。")
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.58))
                        .padding(.top, 8)

                    VStack(spacing: 12) {
                        ForEach(WelcomeIntent.allCases) { intent in
                            intentButton(intent)
                        }
                    }
                    .padding(.top, 32)

                    Button("先自己探索") {
                        Haptics.light()
                        withAnimation(.easeOut(duration: 0.25)) {
                            hasSeenWelcome = true
                        }
                    }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 24)
                    .padding(.bottom, 40)
                }
                .padding(.horizontal, 24)
            }
        }
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeIn(duration: 0.4)) {
                opacity = 1
            }
        }
    }

    private func intentButton(_ intent: WelcomeIntent) -> some View {
        Button {
            guard selectedIntent == nil else { return }
            selectedIntent = intent
            Haptics.medium()

            let scene = ScenePreset.allPresets.first { $0.id == intent.preferredSceneID }
                ?? ScenePreset.allPresets.first
            if let scene {
                ScenePlaybackCoordinator(audioManager: audioManager, videoManager: videoManager).apply(scene)
            }

            withAnimation(.easeOut(duration: 0.3)) {
                hasSeenWelcome = true
            }
        } label: {
            HStack(spacing: 16) {
                Image(systemName: selectedIntent == intent ? "checkmark" : intent.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(intent.color.opacity(0.8)))

                VStack(alignment: .leading, spacing: 5) {
                    Text(intent.rawValue)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(intent.subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.58))
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.42))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(selectedIntent == intent ? intent.color.opacity(0.22) : Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(selectedIntent == intent ? intent.color.opacity(0.8) : Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(selectedIntent != nil)
        .accessibilityLabel("\(intent.rawValue)，\(intent.subtitle)")
        .accessibilityHint("双击后立即开始播放推荐场景")
    }
}
