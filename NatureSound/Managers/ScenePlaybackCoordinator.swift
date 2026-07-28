//
//  ScenePlaybackCoordinator.swift
//  NatureSound
//
//  Created by egbert on 2026/7/27.
//

import SwiftUI

// MARK: - 场景播放协调器

/// 统一应用预设场景与同步锁屏封面，避免多个页面重复维护同一播放流程。
@MainActor
struct ScenePlaybackCoordinator {
    static let lastPresetIDKey = "NatureSound_LastPresetID"

    let audioManager: AudioManager
    let videoManager: VideoManager?

    init(audioManager: AudioManager, videoManager: VideoManager? = nil) {
        self.audioManager = audioManager
        self.videoManager = videoManager
    }

    func apply(_ scene: ScenePreset) {
        audioManager.stopAll()
        for soundID in scene.soundIDs {
            guard let sound = SoundItem.allSounds.first(where: { $0.id == soundID }) else { continue }
            audioManager.addSound(sound, volume: scene.volumes[soundID] ?? 0.7)
        }
        UserDefaults.standard.set(scene.id, forKey: Self.lastPresetIDKey)
        updateNowPlaying(for: scene)
    }

    /// 用户最近一次完整播放的预设场景，用于首页的“继续上次”。
    static var lastPreset: ScenePreset? {
        guard let id = UserDefaults.standard.string(forKey: lastPresetIDKey) else { return nil }
        return ScenePreset.allPresets.first { $0.id == id }
    }

    func apply(_ scene: UserScene) {
        audioManager.stopAll()
        for soundID in scene.soundIDs {
            guard let sound = SoundItem.allSounds.first(where: { $0.id == soundID }) else { continue }
            audioManager.addSound(sound, volume: scene.volumes[soundID] ?? 0.7)
        }
    }

    private func updateNowPlaying(for scene: ScenePreset) {
        guard let videoManager else {
            audioManager.setCurrentScene(id: scene.id, name: scene.name, artwork: nil)
            return
        }

        let artwork = videoManager.nowPlayingArtwork(for: scene.id)
        audioManager.setCurrentScene(id: scene.id, name: scene.name, artwork: artwork)

        guard artwork == nil else { return }
        Task {
            guard let image = await videoManager.fetchNowPlayingArtwork(for: scene.id) else { return }
            audioManager.setCurrentScene(id: scene.id, name: scene.name, artwork: image)
        }
    }
}
