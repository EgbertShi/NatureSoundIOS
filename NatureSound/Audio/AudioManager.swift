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

    /// 全局暂停状态：暂停时保留活跃声音列表，仅停止音频输出。
    var isPaused: Bool = false

    /// 空间音频模式（关闭 / 空间音频 / 环绕声）
    var spatialMode: SpatialMode = .off

    /// 当前正在播放的场景 ID，用于锁屏 Now Playing 封面展示。
    var currentSceneID: String?
    /// 当前场景名称，用于 Now Playing 副标题。
    var currentSceneName: String?

    var activeCount: Int { activePlayers.count }
    var canAddMore: Bool { activePlayers.count < Self.maxConcurrentSounds }

    private var interruptionObserver: NSObjectProtocol?
    private var routeChangeObserver: NSObjectProtocol?
    private var mediaServicesResetObserver: NSObjectProtocol?

    // 环绕声运动
    private var surroundTimer: Foundation.Timer?
    private var surroundPhase: Double = 0

    /// Now Playing 封面图片（锁屏展示用）
    private var nowPlayingArtwork: UIImage?

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

    /// 切换声音的播放/停止状态。返回 false 表示"新增播放"失败（音频文件缺失等），
    /// 调用方可据此向用户展示提示，而不是让卡片停留在"点击无反馈"的状态。
    @discardableResult
    func toggle(_ sound: SoundItem) -> Bool {
        if isPlaying(sound) {
            removeSound(sound)
            return true
        } else {
            return addSound(sound, volume: 0.7)
        }
    }

    func removeSound(_ sound: SoundItem) {
        guard let index = activePlayers.firstIndex(where: { $0.sound.id == sound.id }) else { return }
        activePlayers[index].stop()
        activePlayers.remove(at: index)
        applySpatialLayout()
        updateNowPlayingInfo()
    }

    @discardableResult
    func addSound(_ sound: SoundItem, volume: Float = 0.7) -> Bool {
        guard canAddMore else { return false }
        let player = SoundPlayer(sound: sound)
        player.volume = volume
        let started = player.start(effectiveVolume: volume * masterVolume)
        guard started else {
            // 播放失败（文件缺失/AVAudioPlayer 初始化失败等）：不把这个"僵尸"
            // player 计入 activePlayers，否则会出现卡片显示已选中、
            // 但实际未播放、MiniPlayerBar 状态与音频状态不一致的问题。
            return false
        }
        activePlayers.append(player)
        applySpatialLayout()
        updateNowPlayingInfo()
        return true
    }

    func stopAll() {
        for player in activePlayers { player.stop() }
        activePlayers.removeAll()
        isPaused = false
        currentSceneID = nil
        currentSceneName = nil
        nowPlayingArtwork = nil
        stopSurroundMotion()
        updateNowPlayingInfo()
    }

    // MARK: - 暂停 / 继续

    /// 暂停所有活跃声音（保留列表，可继续播放）。
    func pauseAll() {
        guard !activePlayers.isEmpty, !isPaused else { return }
        isPaused = true
        for player in activePlayers { player.pausePlayback() }
        stopSurroundMotion()
        updateNowPlayingInfo()
    }

    /// 继续播放所有已暂停的声音。
    func playAll() {
        guard !activePlayers.isEmpty, isPaused else { return }
        isPaused = false
        AudioSessionConfig.configure()
        for player in activePlayers {
            player.resumePlayback()
            player.updateVolume(player.volume * masterVolume)
        }
        applySpatialLayout()
        updateNowPlayingInfo()
    }

    /// 在暂停与播放之间切换。
    func togglePlayPause() {
        if isPaused {
            playAll()
        } else {
            pauseAll()
        }
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
        guard !activePlayers.isEmpty, !isPaused else { return }
        AudioSessionConfig.configure()
        for player in activePlayers {
            player.resumeIfNeeded()
            player.updateVolume(player.volume * masterVolume)
        }
        updateNowPlayingInfo()
    }

    /// 强制恢复：无视 isPaused 状态，确保中断后能恢复。
    private func forceResumeAll() {
        guard !activePlayers.isEmpty else { return }
        isPaused = false
        AudioSessionConfig.configure()
        for player in activePlayers {
            player.resumeIfNeeded()
            player.updateVolume(player.volume * masterVolume)
        }
        updateNowPlayingInfo()
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

    // MARK: - 场景封面管理

    /// 设置当前场景信息，用于锁屏 Now Playing 封面展示。
    /// 传入 nil 可清除场景封面。
    func setCurrentScene(id: String?, name: String?, artwork: UIImage?) {
        currentSceneID = id
        currentSceneName = name
        nowPlayingArtwork = artwork
        updateNowPlayingInfo()
    }

    // MARK: - Now Playing

    func updateNowPlayingInfo() {
        #if os(iOS)
        var info: [String: Any] = [:]

        if activePlayers.isEmpty {
            info[MPMediaItemPropertyTitle] = "清籁"
            info[MPMediaItemPropertyArtist] = "清籁"
            info[MPNowPlayingInfoPropertyPlaybackRate] = 0.0
        } else {
            // 标题：使用场景名称（如果有），否则显示声音名称
            if let sceneName = currentSceneName {
                info[MPMediaItemPropertyTitle] = sceneName
                info[MPMediaItemPropertyArtist] = "清籁 · 声音场景"
            } else {
                info[MPMediaItemPropertyTitle] = activePlayers.prefix(3).map { $0.sound.name }.joined(separator: " · ")
                info[MPMediaItemPropertyArtist] = "清籁"
            }
            info[MPNowPlayingInfoPropertyPlaybackRate] = isPaused ? 0.0 : 1.0
        }

        // 播放时长设为 0 表示无限循环
        info[MPMediaItemPropertyPlaybackDuration] = 0
        info[MPNowPlayingInfoPropertyIsLiveStream] = true

        // 锁屏封面图片：优先使用场景缩略图，否则使用 App 图标
        if let artwork = nowPlayingArtwork {
            let mpArtwork = MPMediaItemArtwork(boundsSize: artwork.size) { _ in artwork }
            info[MPMediaItemPropertyArtwork] = mpArtwork
        } else if let appIcon = UIImage(named: "AppIcon") {
            let mpArtwork = MPMediaItemArtwork(boundsSize: appIcon.size) { _ in appIcon }
            info[MPMediaItemPropertyArtwork] = mpArtwork
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        #endif
    }

    // MARK: - 通知与远程控制

    private func setupNotifications() {
        #if os(iOS)
        interruptionObserver = NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] n in self?.handleInterruption(n) }
        routeChangeObserver = NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] n in self?.handleRouteChange(n) }
        mediaServicesResetObserver = NotificationCenter.default.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: .main) { [weak self] _ in
            self?.resumeAll()
        }
        setupRemoteCommands()
        #endif
    }

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.isEnabled = true
        center.playCommand.addTarget { [weak self] _ in
            guard let self, !self.activePlayers.isEmpty else { return .commandFailed }
            self.playAll(); return .success
        }
        center.pauseCommand.isEnabled = true
        center.pauseCommand.addTarget { [weak self] _ in
            guard let self, !self.activePlayers.isEmpty else { return .commandFailed }
            self.pauseAll(); return .success
        }
        center.stopCommand.isEnabled = true
        center.stopCommand.addTarget { [weak self] _ in self?.stopAll(); return .success }
        center.togglePlayPauseCommand.isEnabled = true
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause(); return .success
        }
    }

    private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        switch type {
        case .began:
            break  // 系统中断（电话、Siri 等），播放器会被系统自动暂停
        case .ended:
            // 中断结束，重新激活 session 并恢复播放
            let shouldResume = (userInfo[AVAudioSessionInterruptionOptionKey] as? UInt)
                .flatMap { AVAudioSession.InterruptionOptions(rawValue: $0) }
                .map { $0.contains(.shouldResume) } ?? true
            if shouldResume {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.forceResumeAll()
                }
            }
        @unknown default:
            break
        }
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
