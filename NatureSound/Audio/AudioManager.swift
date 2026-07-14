//
//  AudioManager.swift
//  NatureSound
//
//  Created by egbert on 2026/7/1.
//

import AVFoundation
import SwiftUI
import MediaPlayer

// MARK: - 音频管理器
@Observable
final class AudioManager {
    static let maxConcurrentSounds = 7

    var activePlayers: [SoundPlayer] = []
    var masterVolume: Float = 0.8

    var activeCount: Int { activePlayers.count }
    var canAddMore: Bool { activePlayers.count < Self.maxConcurrentSounds }

    private var interruptionObserver: NSObjectProtocol?
    private var routeChangeObserver: NSObjectProtocol?
    private var mediaServicesResetObserver: NSObjectProtocol?

    init() { setupNotifications() }

    deinit {
        if let obs = interruptionObserver { NotificationCenter.default.removeObserver(obs) }
        if let obs = routeChangeObserver { NotificationCenter.default.removeObserver(obs) }
        if let obs = mediaServicesResetObserver { NotificationCenter.default.removeObserver(obs) }
    }

    // MARK: - 播放控制

    func isPlaying(_ sound: SoundItem) -> Bool {
        activePlayers.contains { $0.sound.id == sound.id }
    }

    func toggle(_ sound: SoundItem) {
        if let index = activePlayers.firstIndex(where: { $0.sound.id == sound.id }) {
            activePlayers[index].stop()
            activePlayers.remove(at: index)
            updateNowPlayingInfo()
        } else {
            addSound(sound, volume: 0.7)
        }
    }

    func addSound(_ sound: SoundItem, volume: Float = 0.7) {
        guard canAddMore else { return }
        let player = SoundPlayer(sound: sound)
        player.volume = volume
        activePlayers.append(player)
        player.start(effectiveVolume: volume * masterVolume)
        updateNowPlayingInfo()
    }

    func stopAll() {
        for player in activePlayers { player.stop() }
        activePlayers.removeAll()
        updateNowPlayingInfo()
    }

    func updateMasterVolume(_ volume: Float) {
        masterVolume = volume
        for player in activePlayers { player.updateVolume(player.volume * masterVolume) }
    }

    func applyFadeOut(progress: Float) {
        let multiplier = 1.0 - progress
        for player in activePlayers { player.updateVolume(player.volume * masterVolume * multiplier) }
    }

    func resumeAll() {
        guard !activePlayers.isEmpty else { return }
        AudioSessionConfig.configure()
        for player in activePlayers {
            player.resumeIfNeeded()
            player.updateVolume(player.volume * masterVolume)
        }
    }

    func playerFor(_ sound: SoundItem) -> SoundPlayer? {
        activePlayers.first { $0.sound.id == sound.id }
    }

    func updateVolume(for sound: SoundItem, volume: Float) {
        if let player = playerFor(sound) { player.updateVolume(volume * masterVolume) }
    }

    // MARK: - Now Playing

    func updateNowPlayingInfo() {
        #if os(iOS)
        var info: [String: Any] = [:]
        info[MPMediaItemPropertyArtist] = "清籁"
        info[MPMediaItemPropertyPlaybackDuration] = 0

        if activePlayers.isEmpty {
            info[MPMediaItemPropertyTitle] = "清籁"
            info[MPNowPlayingInfoPropertyPlaybackRate] = 0.0
        } else {
            info[MPMediaItemPropertyTitle] = activePlayers.prefix(3).map { $0.sound.name }.joined(separator: " · ")
            info[MPNowPlayingInfoPropertyPlaybackRate] = 1.0
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        #endif
    }

    // MARK: - 通知与远程控制

    private func setupNotifications() {
        #if os(iOS)
        interruptionObserver = NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] n in self?.handleInterruption(n) }
        routeChangeObserver = NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] n in self?.handleRouteChange(n) }
        mediaServicesResetObserver = NotificationCenter.default.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: .main) { [weak self] _ in self?.resumeAll() }
        setupRemoteCommands()
        #endif
    }

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.isEnabled = true
        center.playCommand.addTarget { [weak self] _ in
            guard let self, !self.activePlayers.isEmpty else { return .commandFailed }
            self.resumeAll(); return .success
        }
        center.pauseCommand.isEnabled = true
        center.pauseCommand.addTarget { [weak self] _ in self?.stopAll(); return .success }
        center.stopCommand.isEnabled = true
        center.stopCommand.addTarget { [weak self] _ in self?.stopAll(); return .success }
        center.skipForwardCommand.preferredIntervals = [10]
        center.skipForwardCommand.isEnabled = true
        center.skipForwardCommand.addTarget { _ in .success }
        center.skipBackwardCommand.preferredIntervals = [10]
        center.skipBackwardCommand.isEnabled = true
        center.skipBackwardCommand.addTarget { _ in .success }
    }

    private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
        if type == .ended { resumeAll() }
    }

    private func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }
        switch reason {
        case .oldDeviceUnavailable, .newDeviceAvailable, .override, .categoryChange, .routeConfigurationChange:
            resumeAll()
        default: break
        }
    }
}
