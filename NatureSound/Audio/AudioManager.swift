//
//  AudioManager.swift
//  NatureSound
//
//  Created by egbert on 2026/7/1.
//

import AVFoundation
import SwiftUI
import MediaPlayer

// MARK: - 空间音频模式
enum SpatialMode: String, CaseIterable, Identifiable {
    case off        = "关闭"
    case spatial    = "空间音频"
    case surround   = "环绕声"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .off:      return "speaker.wave.2"
        case .spatial:  return "airpodspro"
        case .surround: return "airpods.gen3"
        }
    }
}

// MARK: - 音频管理器
@Observable
final class AudioManager {
    static let maxConcurrentSounds = 7
    private static let spatialModeKey = "NatureSound_SpatialMode"

    var activePlayers: [SoundPlayer] = []
    var masterVolume: Float = 0.8

    /// 空间音频模式（关闭 / 空间音频 / 环绕声）
    var spatialMode: SpatialMode = .off

    var activeCount: Int { activePlayers.count }
    var canAddMore: Bool { activePlayers.count < Self.maxConcurrentSounds }

    // 共享音频引擎：所有 SoundPlayer 的节点接入同一个 engine 的主混音器
    private let engine = AVAudioEngine()

    private var interruptionObserver: NSObjectProtocol?
    private var routeChangeObserver: NSObjectProtocol?
    private var mediaServicesResetObserver: NSObjectProtocol?

    // 环绕声运动
    private var surroundTimer: Foundation.Timer?
    private var surroundPhase: Double = 0

    init() {
        if let raw = UserDefaults.standard.string(forKey: Self.spatialModeKey),
           let mode = SpatialMode(rawValue: raw) {
            spatialMode = mode
        }
        setupNotifications()
    }

    deinit {
        if let obs = interruptionObserver { NotificationCenter.default.removeObserver(obs) }
        if let obs = routeChangeObserver { NotificationCenter.default.removeObserver(obs) }
        if let obs = mediaServicesResetObserver { NotificationCenter.default.removeObserver(obs) }
        surroundTimer?.invalidate()
    }

    // MARK: - 播放控制

    func isPlaying(_ sound: SoundItem) -> Bool {
        activePlayers.contains { $0.sound.id == sound.id }
    }

    func toggle(_ sound: SoundItem) {
        if isPlaying(sound) {
            removeSound(sound)
        } else {
            addSound(sound, volume: 0.7)
        }
    }

    func removeSound(_ sound: SoundItem) {
        guard let index = activePlayers.firstIndex(where: { $0.sound.id == sound.id }) else { return }
        activePlayers[index].stop()
        activePlayers.remove(at: index)
        applySpatialLayout()
        updateNowPlayingInfo()
    }

    func addSound(_ sound: SoundItem, volume: Float = 0.7) {
        guard canAddMore else { return }
        let player = SoundPlayer(sound: sound, engine: engine)
        player.volume = volume
        activePlayers.append(player)
        player.start(effectiveVolume: volume * masterVolume)
        applySpatialLayout()
        updateNowPlayingInfo()
    }

    func stopAll() {
        for player in activePlayers { player.stop() }
        activePlayers.removeAll()
        stopSurroundMotion()
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

    // MARK: - 空间音频

    /// 切换空间音频模式，持久化并立即应用到当前活跃声音。
    func setSpatialMode(_ mode: SpatialMode) {
        spatialMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: Self.spatialModeKey)
        applySpatialLayout()
    }

    /// 根据当前模式重新布局所有声音的声道。
    private func applySpatialLayout() {
        switch spatialMode {
        case .off:
            stopSurroundMotion()
            for player in activePlayers { player.updatePan(0) }
        case .spatial:
            stopSurroundMotion()
            redistributePans()
        case .surround:
            redistributePans()
            startSurroundMotion()
        }
    }

    /// 将当前所有活跃声音的声道从左 -0.8 到右 0.8 均匀分布。
    func redistributePans() {
        let count = activePlayers.count
        guard count > 0 else { return }
        if count == 1 {
            activePlayers[0].updatePan(0)
            return
        }
        for (index, player) in activePlayers.enumerated() {
            let t = Float(index) / Float(count - 1)   // 0...1
            let pan = -0.8 + t * 1.6                    // -0.8...0.8
            player.updatePan(pan)
        }
    }

    // MARK: - 环绕声运动
    // 每个声音以不同频率做正弦声像运动，营造环绕包围感。

    private func startSurroundMotion() {
        stopSurroundMotion()
        surroundPhase = 0
        let timer = Foundation.Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.tickSurround()
        }
        RunLoop.main.add(timer, forMode: .common)
        surroundTimer = timer
    }

    private func stopSurroundMotion() {
        surroundTimer?.invalidate()
        surroundTimer = nil
    }

    private func tickSurround() {
        surroundPhase += 1.0 / 30.0
        for (index, player) in activePlayers.enumerated() {
            // 每个声音使用不同频率与相位偏移，避免声像同步
            let freq = 0.05 + Double(index) * 0.02      // 慢速运动，0.05~0.17 Hz
            let phaseOffset = Double(index) * .pi / Double(max(1, activePlayers.count))
            let pan = Float(sin(surroundPhase * 2 * .pi * freq + phaseOffset)) * 0.8
            player.updatePan(pan)
        }
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
