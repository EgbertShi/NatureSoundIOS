//
//  SoundPlayer.swift
//  NatureSound
//
//  Created by egbert on 2026/7/1.
//

import AVFoundation
import SwiftUI

// MARK: - 声音播放模式
/// 区分连续型声音（雨、风、溪流等）和间歇型声音（鸟鸣、虫鸣、钟声等）。
/// 连续型声音使用 numberOfLoops = -1 无限循环；
/// 间歇型声音每次播放完毕后随机等待一段时间再播下一次，
/// 并在每次播放时微调音量和起始位置，消除机械重复感。
private enum PlaybackMode {
    /// 连续循环（雨声、风声、溪流、火焰、森林等连续声景）
    case continuous
    /// 间歇随机（鸟鸣、虫鸣、禅意器物、部分氛围等有节奏的声音）
    /// - minGap / maxGap：两次播放之间的随机等待秒数范围
    /// - volumeJitter：每次播放时音量在基准上下浮动的比例（0.1 = ±10%）
    case intermittent(minGap: Double, maxGap: Double, volumeJitter: Float)

    // MARK: - 根据声音分类和音频时长自动判断播放模式

    static func forSound(_ sound: SoundItem, duration: Double) -> PlaybackMode {
        let cat = sound.category.rawValue

        // 鸟鸣：短录音（单次叫声）间歇更长，长录音（鸟鸣合奏）间歇短
        if cat == "鸟鸣" {
            if duration < 5 {
                // 极短的单声叫（猫头鹰、乌鸦、雄鸡等）
                return .intermittent(minGap: 4.0, maxGap: 15.0, volumeJitter: 0.2)
            } else if duration < 10 {
                return .intermittent(minGap: 2.0, maxGap: 8.0, volumeJitter: 0.15)
            } else {
                // 较长的鸟鸣录音，间歇短一些
                return .intermittent(minGap: 1.0, maxGap: 4.0, volumeJitter: 0.1)
            }
        }

        // 虫鸣：蟋蟀、蝉等有节奏的叫声
        if cat == "虫鸣" {
            if duration < 10 {
                return .intermittent(minGap: 1.5, maxGap: 6.0, volumeJitter: 0.15)
            } else {
                return .intermittent(minGap: 0.5, maxGap: 3.0, volumeJitter: 0.1)
            }
        }

        // 禅意：钟声、铜锣等有明显"敲击-衰减"特征的声音
        if cat == "禅意" {
            let sid = sound.id
            // 梵音吟唱和编钟是较连续的声音，用短间歇
            if sid == "mantra" || sid == "tibetan_chant" || sid == "zen_bell" {
                return .intermittent(minGap: 0.5, maxGap: 2.0, volumeJitter: 0.1)
            }
            // 钟声、铜锣、风铃：单次敲击，间歇长
            return .intermittent(minGap: 5.0, maxGap: 18.0, volumeJitter: 0.2)
        }

        // 氛围类中部分间歇性声音
        if cat == "氛围" {
            let sid = sound.id
            // 蛙声类
            if sid.contains("frog") {
                return .intermittent(minGap: 1.0, maxGap: 5.0, volumeJitter: 0.15)
            }
            // 蟋蟀类
            if sid.contains("cricket") {
                return .intermittent(minGap: 1.0, maxGap: 5.0, volumeJitter: 0.15)
            }
        }

        // 其他所有：连续循环
        return .continuous
    }
}

// MARK: - 单个声音播放器（AVAudioPlayer 架构，原生支持后台播放）
// AVAudioPlayer 配合 .playback category + UIBackgroundModes audio，
// 是 iOS 上最可靠的后台音频播放方案。
@Observable
final class SoundPlayer: Identifiable {
    let id: String
    let sound: SoundItem
    var volume: Float = 0.7
    var isPlaying: Bool = false

    /// 声道平衡：-1.0 全左，0 居中，1.0 全右
    var pan: Float = 0.0

    /// 声道指示标签（供 UI 显示 L/R/C）
    var channelLabel: String {
        if pan < -0.15 { return "L" }
        if pan > 0.15 { return "R" }
        return "C"
    }

    // AVAudioPlayer：原生支持后台播放、无限循环、音量和声道控制
    private var audioPlayer: AVAudioPlayer?

    // 音量渐变
    private var fadeTimer: Timer?
    private var targetVolume: Float = 0
    // 暂停前的音量，用于 resumePlayback() 还原
    private var volumeBeforePause: Float = 0

    // MARK: - 间歇播放状态
    private var playbackMode: PlaybackMode = .continuous
    /// 音频文件总时长（秒）
    private var audioDuration: Double = 0
    /// 间歇等待定时器
    private var gapTimer: Timer?
    /// 用于接收 AVAudioPlayerDelegate 回调的桥接对象
    private var delegateBridge: PlayerDelegateBridge?
    /// 当前播放生效的音量（含主音量系数），间歇播放结束后用于重新淡入
    private var currentEffectiveVolume: Float = 0

    init(sound: SoundItem) {
        self.id = sound.id
        self.sound = sound
    }

    // MARK: - 播放控制

    /// 启动播放。返回 false 表示音频文件缺失或播放失败，调用方（AudioManager）
    /// 应据此避免把一个"未真正播放"的 SoundPlayer 计入 activePlayers。
    @discardableResult
    func start(effectiveVolume: Float? = nil) -> Bool {
        guard !isPlaying else { return true }
        AudioSessionConfig.configure()

        let subdirectory = "Sounds/\(sound.category.rawValue)"
        guard let url = Bundle.main.url(forResource: sound.fileName, withExtension: "m4a", subdirectory: subdirectory)
            ?? Bundle.main.url(forResource: sound.fileName, withExtension: "m4a") else {
            print("[SoundPlayer] 未找到音频文件: \(sound.fileName) (category: \(sound.category.rawValue))")
            isPlaying = false
            return false
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            audioDuration = player.duration
            playbackMode = PlaybackMode.forSound(sound, duration: audioDuration)

            switch playbackMode {
            case .continuous:
                player.numberOfLoops = -1
            case .intermittent:
                player.numberOfLoops = 0   // 播放一次即停
            }

            player.volume = 0               // 从 0 开始，渐入
            player.pan = pan                // 声道平衡

            // 间歇模式：随机起始位置（避免每次都从同一个点开始）
            if case .intermittent = playbackMode, audioDuration > 1.0 {
                let maxOffset = max(0, audioDuration - 0.5)
                player.currentTime = Double.random(in: 0...maxOffset)
            }

            player.prepareToPlay()

            // 先持有引用，防止 ARC 提前释放
            audioPlayer = player

            // 间歇模式：设置 delegate 监听播放结束
            if case .intermittent = playbackMode {
                let bridge = PlayerDelegateBridge { [weak self] in
                    self?.onIntermittentPlaybackFinished()
                }
                delegateBridge = bridge
                player.delegate = bridge
            }

            if player.play() {
                isPlaying = true
                let vol = effectiveVolume ?? self.volume
                currentEffectiveVolume = vol
                fadeVolume(to: vol, duration: 1.5)
                return true
            } else {
                audioPlayer = nil
                isPlaying = false
                print("[SoundPlayer] 播放启动失败: \(sound.fileName)")
                return false
            }
        } catch {
            print("[SoundPlayer] 播放失败: \(error)")
            isPlaying = false
            return false
        }
    }

    func resumeIfNeeded() {
        guard isPlaying, let player = audioPlayer else { return }
        AudioSessionConfig.configure()
        if !player.isPlaying {
            // 如果是间歇模式且处于间歇等待中，不要强制重播，让 gapTimer 自行处理
            if case .intermittent = playbackMode, gapTimer != nil {
                return
            }
            player.currentTime = 0
            switch playbackMode {
            case .continuous:
                player.numberOfLoops = -1
            case .intermittent:
                player.numberOfLoops = 0
            }
            player.play()
        }
    }

    func stop() {
        guard isPlaying else { return }
        isPlaying = false
        fadeTimer?.invalidate()
        fadeTimer = nil
        gapTimer?.invalidate()
        gapTimer = nil
        delegateBridge = nil
        audioPlayer?.delegate = nil
        audioPlayer?.stop()
        audioPlayer = nil
    }

    /// 暂停：保留播放器实例，可通过 resumePlayback() 恢复。
    func pausePlayback() {
        fadeTimer?.invalidate()
        fadeTimer = nil
        gapTimer?.invalidate()
        gapTimer = nil
        volumeBeforePause = targetVolume
        audioPlayer?.pause()
    }

    /// 恢复由 pausePlayback() 暂停的播放。
    func resumePlayback() {
        guard isPlaying, let player = audioPlayer else { return }
        AudioSessionConfig.configure()
        player.volume = volumeBeforePause
        player.play()
        targetVolume = volumeBeforePause
        currentEffectiveVolume = volumeBeforePause

        // 间歇模式下恢复后，若播放器已到末尾，重新触发间歇调度
        if case .intermittent = playbackMode, !player.isPlaying {
            scheduleNextIntermittentPlay()
        }
    }

    /// 更新有效音量（已包含主音量系数）
    func updateVolume(_ v: Float) {
        targetVolume = v
        currentEffectiveVolume = v
        audioPlayer?.volume = v
    }

    /// 更新声道平衡
    func updatePan(_ p: Float) {
        pan = max(-1.0, min(1.0, p))
        audioPlayer?.pan = pan
    }

    // MARK: - 间歇播放调度

    /// 当间歇模式下一次播放结束时调用
    private func onIntermittentPlaybackFinished() {
        guard isPlaying, case .intermittent = playbackMode else { return }
        scheduleNextIntermittentPlay()
    }

    /// 安排下一次间歇播放：随机等待后重新播放
    private func scheduleNextIntermittentPlay() {
        guard isPlaying, case let .intermittent(minGap, maxGap, _) = playbackMode else { return }

        gapTimer?.invalidate()
        let gap = Double.random(in: minGap...maxGap)

        let timer = Timer(timeInterval: gap, repeats: false) { [weak self] _ in
            self?.startNextIntermittentCycle()
        }
        RunLoop.main.add(timer, forMode: .common)
        gapTimer = timer
    }

    /// 开始下一次间歇播放周期
    private func startNextIntermittentCycle() {
        guard isPlaying, let player = audioPlayer,
              case let .intermittent(_, _, volumeJitter) = playbackMode else { return }

        gapTimer = nil

        // 随机微调音量（在当前有效音量基础上 ±jitter）
        let jitteredVolume = currentEffectiveVolume * Float.random(in: (1.0 - volumeJitter)...(1.0 + volumeJitter))

        // 随机起始位置（只在音频足够长时偏移）
        if audioDuration > 1.0 {
            let maxOffset = max(0, audioDuration * 0.3)  // 最多偏移前 30%
            player.currentTime = Double.random(in: 0...maxOffset)
        } else {
            player.currentTime = 0
        }

        player.volume = 0
        player.numberOfLoops = 0
        player.play()

        // 短淡入，避免突然出声
        fadeVolume(to: jitteredVolume, duration: 0.3)
    }

    // MARK: - 内部实现

    private func fadeVolume(to target: Float, duration: Double, completion: (() -> Void)? = nil) {
        fadeTimer?.invalidate()
        targetVolume = target
        let start = audioPlayer?.volume ?? 0
        let steps = max(1, Int(duration * 60))
        var currentStep = 0
        let timer = Timer(timeInterval: duration / Double(steps), repeats: true) { [weak self] t in
            guard let self else { t.invalidate(); return }
            currentStep += 1
            let progress = Float(currentStep) / Float(steps)
            self.audioPlayer?.volume = start + (target - start) * progress
            if currentStep >= steps {
                self.audioPlayer?.volume = target
                t.invalidate()
                self.fadeTimer = nil
                completion?()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        fadeTimer = timer
    }
}

// MARK: - AVAudioPlayerDelegate 桥接
/// 用于接收 AVAudioPlayer 播放完毕回调，桥接到 SoundPlayer 的间歇调度逻辑。
private final class PlayerDelegateBridge: NSObject, AVAudioPlayerDelegate {
    private let onFinished: () -> Void

    init(onFinished: @escaping () -> Void) {
        self.onFinished = onFinished
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        // 确保在主线程回调
        if Thread.isMainThread {
            onFinished()
        } else {
            DispatchQueue.main.async { [self] in
                self.onFinished()
            }
        }
    }
}
