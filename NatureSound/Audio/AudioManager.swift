//
//  AudioManager.swift
//  NatureSound
//
//  Created by egbert on 2026/7/1.
//

import AVFoundation
import SwiftUI
import MediaPlayer
import os

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

    // MARK: - 间歇声协调
    /// 记录最近一次间歇声触发的时间戳，用于错开多个间歇声的触发时机
    private var lastIntermittentTriggerTime: Date?
    /// 间歇声最小间隔（秒），避免多个间歇声同时触发
    private static let intermittentMinSpacing: Double = 1.5

    /// 间歇声触发前调用：检查距离上一次触发是否足够远，返回需要额外等待的秒数。
    /// 返回 0 表示可以立即触发。
    func intermittentSpacingDelay() -> Double {
        guard let last = lastIntermittentTriggerTime else { return 0 }
        let elapsed = Date().timeIntervalSince(last)
        let remaining = Self.intermittentMinSpacing - elapsed
        return max(0, remaining)
    }

    /// 间歇声实际触发后调用，更新时间戳。
    func markIntermittentTrigger() {
        lastIntermittentTriggerTime = Date()
    }

    /// Now Playing 封面图片（锁屏展示用）
    private var nowPlayingArtwork: UIImage?
    /// Now Playing 动态封面视频 URL（锁屏视频背景用，iOS 26+）
    private var nowPlayingVideoURL: URL?

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
        player.coordinator = self  // 间歇声协调引用
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
        nowPlayingVideoURL = nil
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
        // 使用指数曲线（平方），前半段缓慢衰减、后半段加速收尾，听感更自然
        let multiplier = pow(max(0, 1.0 - progress), 2.0)
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

    /// 按声音特性分配声像位置。
    /// 环境基底声（雨、风、水流、火焰等）居中铺底；
    /// 点状声源（鸟鸣、虫鸣、钟声等）分散到左右两侧。
    func redistributePans() {
        let count = activePlayers.count
        guard count > 0 else { return }
        if count == 1 {
            activePlayers[0].updatePan(0)
            return
        }

        // 将声音分为两组：基底声（居中）和点状声（分散）
        var baseIndices: [Int] = []
        var pointIndices: [Int] = []
        for (index, player) in activePlayers.enumerated() {
            if player.sound.isAmbientBase {
                baseIndices.append(index)
            } else {
                pointIndices.append(index)
            }
        }

        // 基底声在 -0.2...0.2 之间窄幅分布
        for (i, idx) in baseIndices.enumerated() {
            if baseIndices.count == 1 {
                activePlayers[idx].updatePan(0)
            } else {
                let t = Float(i) / Float(baseIndices.count - 1)
                let pan = -0.2 + t * 0.4
                activePlayers[idx].updatePan(pan)
            }
        }

        // 点状声在 -0.8...0.8 之间宽幅分布
        for (i, idx) in pointIndices.enumerated() {
            if pointIndices.count == 1 {
                activePlayers[idx].updatePan(0)
            } else {
                let t = Float(i) / Float(pointIndices.count - 1)
                let pan = -0.8 + t * 1.6
                activePlayers[idx].updatePan(pan)
            }
        }
    }

    // MARK: - 环绕声运动
    // 每个声音以不同频率做正弦声像运动，营造环绕包围感。

    private func startSurroundMotion() {
        stopSurroundMotion()
        surroundPhase = 0
        // 10fps 足够人耳感知声像变化，降低整夜播放时的 CPU 和电量消耗
        let timer = Foundation.Timer(timeInterval: 1.0 / 10.0, repeats: true) { [weak self] _ in
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
        surroundPhase += 1.0 / 10.0
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
    /// - Parameters:
    ///   - id: 场景 ID
    ///   - name: 场景名称
    ///   - artwork: 静态封面图（用于 Now Playing 控件和动态封面加载前的预览图）
    ///   - videoURL: 场景视频本地 URL（用于 iOS 26+ 锁屏动态视频背景）
    func setCurrentScene(id: String?, name: String?, artwork: UIImage?, videoURL: URL? = nil) {
        currentSceneID = id
        currentSceneName = name
        nowPlayingArtwork = artwork
        nowPlayingVideoURL = videoURL
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

        // iOS 26+ 锁屏动态视频封面（MPMediaItemAnimatedArtwork）
        // 当场景有已缓存的视频时，在锁屏"正在播放"界面展示循环视频背景
        setAnimatedArtwork(info: &info)

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        #endif
    }

    /// 设置锁屏动态视频封面（iOS 26+）。
    /// 通过 MPNowPlayingInfoCenter.supportedAnimatedArtworkKeys 获取系统支持的动态封面 key，
    /// 为每个 key 创建 MPMediaItemAnimatedArtwork 对象，提供视频文件 URL 和静态预览图。
    ///
    /// 重要：系统要求视频和预览图的宽高比必须匹配对应的 key（3x4 → 3:4 竖屏比例）。
    /// 因此需要将横屏视频裁剪为竖屏比例后再提供给系统。
    private func setAnimatedArtwork(info: inout [String: Any]) {
        #if os(iOS)
        guard let videoURL = nowPlayingVideoURL else {
            AppLogger.audio.debug("动态封面: 无视频 URL，跳过")
            return
        }
        let previewImage = nowPlayingArtwork

        // 获取系统支持的动态封面属性 key
        let supportedKeys = MPNowPlayingInfoCenter.supportedAnimatedArtworkKeys
        AppLogger.audio.info("动态封面: 视频 URL = \(videoURL.lastPathComponent, privacy: .public), supportedKeys = \(supportedKeys, privacy: .public)")
        guard !supportedKeys.isEmpty else {
            AppLogger.audio.info("动态封面: 系统不支持动态封面 key，跳过")
            return
        }

        // 用场景 ID 作为 artworkID，确保同一场景的封面可被系统缓存复用
        let artworkID = currentSceneID ?? UUID().uuidString

        for key in supportedKeys {
            // 根据 key 确定目标宽高比
            let targetAspectRatio: CGFloat = key.contains("1x1") ? 1.0 : 3.0 / 4.0

            let localVideoURL = videoURL
            let localPreviewImage = previewImage
            let localArtworkID = artworkID

            let animatedArtwork = MPMediaItemAnimatedArtwork(
                artworkID: localArtworkID,
                previewImageRequestHandler: { size in
                    AppLogger.audio.debug("动态封面: 系统请求预览图，size = \(size.debugDescription, privacy: .public)")
                    // 将预览图裁剪为目标宽高比
                    if let image = localPreviewImage {
                        return Self.cropImageToAspectRatio(image, targetRatio: targetAspectRatio)
                    }
                    return nil
                },
                videoAssetFileURLRequestHandler: { size in
                    AppLogger.audio.info("动态封面: 系统请求视频文件，size = \(size.debugDescription, privacy: .public), 源视频 = \(localVideoURL.lastPathComponent, privacy: .public)")
                    // 将视频裁剪为目标宽高比后返回本地文件 URL
                    do {
                        let croppedURL = try await Self.cropVideoToAspectRatio(
                            sourceURL: localVideoURL,
                            targetRatio: targetAspectRatio,
                            artworkID: localArtworkID,
                            keySuffix: key.contains("1x1") ? "1x1" : "3x4"
                        )
                        AppLogger.audio.info("动态封面: 裁剪视频完成 → \(croppedURL.lastPathComponent, privacy: .public)")
                        return croppedURL
                    } catch {
                        AppLogger.audio.error("动态封面: 裁剪视频失败: \(error.localizedDescription, privacy: .public)")
                        return nil
                    }
                }
            )
            info[key] = animatedArtwork
            AppLogger.audio.info("动态封面: 已设置 key = \(key, privacy: .public)")
        }
        #endif
    }

    // MARK: - 动态封面裁剪工具

    /// 将图片从中心裁剪为指定宽高比（targetRatio = width / height）。
    private static func cropImageToAspectRatio(_ image: UIImage, targetRatio: CGFloat) -> UIImage {
        let originalSize = image.size
        let originalRatio = originalSize.width / originalSize.height

        // 已经匹配则直接返回
        if abs(originalRatio - targetRatio) < 0.05 { return image }

        var cropRect: CGRect
        if originalRatio > targetRatio {
            // 原图更宽，裁剪左右
            let newWidth = originalSize.height * targetRatio
            let xOffset = (originalSize.width - newWidth) / 2
            cropRect = CGRect(x: xOffset, y: 0, width: newWidth, height: originalSize.height)
        } else {
            // 原图更高，裁剪上下
            let newHeight = originalSize.width / targetRatio
            let yOffset = (originalSize.height - newHeight) / 2
            cropRect = CGRect(x: 0, y: yOffset, width: originalSize.width, height: newHeight)
        }

        // 转换为像素坐标
        let scale = image.scale
        let pixelRect = CGRect(
            x: cropRect.origin.x * scale,
            y: cropRect.origin.y * scale,
            width: cropRect.width * scale,
            height: cropRect.height * scale
        )

        guard let cgImage = image.cgImage?.cropping(to: pixelRect) else { return image }
        return UIImage(cgImage: cgImage, scale: scale, orientation: image.imageOrientation)
    }

    /// 将视频从中心裁剪为指定宽高比（targetRatio = width / height），导出到缓存目录。
    /// 已裁剪的视频会缓存在本地，相同 artworkID + keySuffix 不会重复裁剪。
    private static func cropVideoToAspectRatio(
        sourceURL: URL,
        targetRatio: CGFloat,
        artworkID: String,
        keySuffix: String
    ) async throws -> URL {
        // 缓存目录
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AnimatedArtwork", isDirectory: true)
        if !FileManager.default.fileExists(atPath: cacheDir.path) {
            try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        }

        // 缓存文件名：artworkID_keySuffix.mp4
        let safeID = artworkID.replacingOccurrences(of: "/", with: "_")
        let outputURL = cacheDir.appendingPathComponent("\(safeID)_\(keySuffix).mp4")

        // 已有缓存直接返回
        if FileManager.default.fileExists(atPath: outputURL.path) {
            AppLogger.audio.debug("动态封面: 使用缓存裁剪视频 \(outputURL.lastPathComponent, privacy: .public)")
            return outputURL
        }

        let asset = AVAsset(url: sourceURL)

        // 获取视频轨道的原始尺寸
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw NSError(domain: "AnimatedArtwork", code: -1, userInfo: [NSLocalizedDescriptionKey: "无视频轨道"])
        }
        let naturalSize = try await videoTrack.load(.naturalSize)
        let transform = try await videoTrack.load(.preferredTransform)
        // 考虑 transform 后的实际尺寸
        let transformedSize = naturalSize.applying(transform)
        let videoWidth = abs(transformedSize.width)
        let videoHeight = abs(transformedSize.height)
        let videoRatio = videoWidth / videoHeight

        AppLogger.audio.info("动态封面: 源视频尺寸 \(Int(videoWidth))×\(Int(videoHeight))，比例 \(String(format: "%.2f", videoRatio), privacy: .public)，目标比例 \(String(format: "%.2f", targetRatio), privacy: .public)")

        // 如果已经匹配目标比例，直接返回原视频
        if abs(videoRatio - targetRatio) < 0.05 {
            return sourceURL
        }

        // 计算裁剪区域（基于原始 naturalSize 坐标系）
        var cropRect: CGRect
        if videoRatio > targetRatio {
            // 视频更宽，裁剪左右（取中间部分）
            let newWidth = videoHeight * targetRatio
            let xOffset = (videoWidth - newWidth) / 2
            cropRect = CGRect(x: xOffset, y: 0, width: newWidth, height: videoHeight)
        } else {
            // 视频更高，裁剪上下
            let newHeight = videoWidth / targetRatio
            let yOffset = (videoHeight - newHeight) / 2
            cropRect = CGRect(x: 0, y: yOffset, width: videoWidth, height: newHeight)
        }

        let renderWidth = cropRect.width
        let renderHeight = cropRect.height

        // 构建 AVMutableVideoComposition 进行裁剪
        let composition = AVMutableVideoComposition()
        composition.frameDuration = CMTime(value: 1, timescale: 30)
        composition.renderSize = CGSize(width: renderWidth, height: renderHeight)

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: try await asset.load(.duration))

        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        // 平移使裁剪区域居中
        let cropTransform = transform.concatenating(CGAffineTransform(translationX: -cropRect.origin.x, y: -cropRect.origin.y))
        layerInstruction.setTransform(cropTransform, at: .zero)
        instruction.layerInstructions = [layerInstruction]
        composition.instructions = [instruction]

        // 导出
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            throw NSError(domain: "AnimatedArtwork", code: -2, userInfo: [NSLocalizedDescriptionKey: "无法创建导出会话"])
        }
        // 清除旧文件
        try? FileManager.default.removeItem(at: outputURL)
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.videoComposition = composition

        await exportSession.export()

        if exportSession.status == .completed {
            return outputURL
        } else {
            let errorMsg = exportSession.error?.localizedDescription ?? "未知错误"
            throw NSError(domain: "AnimatedArtwork", code: -3, userInfo: [NSLocalizedDescriptionKey: "导出失败: \(errorMsg)"])
        }
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
