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
    @State private var selectedCategory: SoundCategory = .all
    @State private var showLimitAlert = false

    private var columns: [GridItem] { [GridItem(.adaptive(minimum: 100), spacing: 12)] }
    private var filteredSounds: [SoundItem] { SoundItem.sounds(for: selectedCategory) }

    var body: some View {
        VStack(spacing: 0) {
            CategoryTabView(selectedCategory: $selectedCategory)
                .padding(.top, 8)

            activeCountBadge
                .padding(.top, 12)
                .padding(.horizontal, 20)

            ScrollView(showsIndicators: false) {
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
        .alert("已达叠加上限", isPresented: $showLimitAlert) {
            Button("我知道了", role: .cancel) {}
        } message: {
            Text("最多同时叠加 \(AudioManager.maxConcurrentSounds) 种声音，请先关闭部分声音后再添加新的声音。")
        }
    }

    private var activeCountBadge: some View {
        HStack(spacing: 6) {
            let remaining = AudioManager.maxConcurrentSounds - audioManager.activeCount

            if audioManager.activeCount > 0 {
                Image(systemName: "waveform")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(hex: "667eea"))
                Text("已选 \(audioManager.activeCount) 种")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.6))
                Text("·").foregroundStyle(Color.white.opacity(0.3))
                Text("还可添加 \(remaining) 种")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(remaining <= 2 ? Color(hex: "FF6B6B").opacity(0.8) : Color.white.opacity(0.4))
            } else {
                Image(systemName: "hand.tap")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.3))
                Text("点击声音卡片开始叠加播放")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.4))
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
