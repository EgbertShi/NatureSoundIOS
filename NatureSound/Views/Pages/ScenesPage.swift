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

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                Text("推荐场景")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.8))
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                    ForEach(ScenePreset.allPresets) { preset in
                        SceneCard(preset: preset) { applyPreset(preset) }
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, audioManager.activeCount > 0 ? 160 : 40)
        }
    }

    private func applyPreset(_ preset: ScenePreset) {
        Haptics.medium()
        audioManager.stopAll()
        for soundID in preset.soundIDs {
            if let sound = SoundItem.allSounds.first(where: { $0.id == soundID }) {
                audioManager.addSound(sound, volume: preset.volumes[soundID] ?? 0.7)
            }
        }
    }
}
