//
//  SoundPlayer.swift
//  NatureSound
//
//  Created by egbert on 2026/7/1.
//

import AVFoundation
import SwiftUI

// MARK: - 单个声音播放器（AVAudioEngine 架构，支持独立声道 pan）
// 播放链路：AVAudioPlayerNode -> 独立 AVAudioMixerNode(panner) -> engine 主混音器
// panner 节点用于每个声音独立的左右声道平衡控制（-1.0 全左 ~ 1.0 全右），
// 从而支持空间音频 / 环绕声效果。
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

    // 音频引擎节点
    private let engine: AVAudioEngine
    private let playerNode = AVAudioPlayerNode()
    private let panner = AVAudioMixerNode()

    private var audioFile: AVAudioFile?
    private var isAttached = false

    // 音量渐变
    private var fadeTimer: Timer?
    private var targetVolume: Float = 0

    init(sound: SoundItem, engine: AVAudioEngine) {
        self.id = sound.id
        self.sound = sound
        self.engine = engine
    }

    // MARK: - 播放控制

    func start(effectiveVolume: Float? = nil) {
        guard !isPlaying else { return }
        AudioSessionConfig.configure()

        let subdirectory = "Sounds/\(sound.category.rawValue)"
        guard let url = Bundle.main.url(forResource: sound.fileName, withExtension: "m4a", subdirectory: subdirectory)
            ?? Bundle.main.url(forResource: sound.fileName, withExtension: "m4a") else {
            print("[SoundPlayer] 未找到音频文件: \(sound.fileName) (category: \(sound.category.rawValue))")
            isPlaying = false
            return
        }

        do {
            let file = try AVAudioFile(forReading: url)
            audioFile = file
            attachIfNeeded(format: file.processingFormat)

            if !engine.isRunning {
                try engine.start()
            }

            panner.outputVolume = 0
            panner.pan = pan
            scheduleLoop(file: file)
            playerNode.play()
            isPlaying = true

            let vol = effectiveVolume ?? self.volume
            fadeVolume(to: vol, duration: 1.5)
        } catch {
            print("[SoundPlayer] 播放失败: \(error)")
            isPlaying = false
        }
    }

    func resumeIfNeeded() {
        guard isPlaying, let file = audioFile else { return }
        AudioSessionConfig.configure()
        do {
            if !engine.isRunning { try engine.start() }
            if !playerNode.isPlaying {
                scheduleLoop(file: file)
                playerNode.play()
            }
        } catch {
            print("[SoundPlayer] 恢复失败: \(error)")
        }
    }

    func stop() {
        guard isPlaying else { return }
        isPlaying = false
        fadeVolume(to: 0, duration: 0.5) { [weak self] in
            guard let self else { return }
            self.playerNode.stop()
            self.detach()
            self.audioFile = nil
        }
    }

    /// 更新有效音量（已包含主音量系数）
    func updateVolume(_ v: Float) {
        targetVolume = v
        panner.outputVolume = v
    }

    /// 更新声道平衡
    func updatePan(_ p: Float) {
        pan = max(-1.0, min(1.0, p))
        panner.pan = pan
    }

    // MARK: - 内部实现

    private func attachIfNeeded(format: AVAudioFormat) {
        guard !isAttached else { return }
        engine.attach(playerNode)
        engine.attach(panner)
        engine.connect(playerNode, to: panner, format: format)
        engine.connect(panner, to: engine.mainMixerNode, format: format)
        isAttached = true
    }

    private func detach() {
        guard isAttached else { return }
        engine.disconnectNodeOutput(playerNode)
        engine.disconnectNodeOutput(panner)
        engine.detach(playerNode)
        engine.detach(panner)
        isAttached = false
    }

    /// 无缝循环：使用 AVAudioPlayerNode 的 completion 重新排程实现无限循环。
    private func scheduleLoop(file: AVAudioFile) {
        file.framePosition = 0
        playerNode.scheduleFile(file, at: nil) { [weak self] in
            guard let self, self.isPlaying else { return }
            DispatchQueue.main.async {
                guard self.isPlaying, let f = self.audioFile else { return }
                self.scheduleLoop(file: f)
            }
        }
    }

    private func fadeVolume(to target: Float, duration: Double, completion: (() -> Void)? = nil) {
        fadeTimer?.invalidate()
        targetVolume = target
        let start = panner.outputVolume
        let steps = max(1, Int(duration * 60))
        var currentStep = 0
        let timer = Timer(timeInterval: duration / Double(steps), repeats: true) { [weak self] t in
            guard let self else { t.invalidate(); return }
            currentStep += 1
            let progress = Float(currentStep) / Float(steps)
            self.panner.outputVolume = start + (target - start) * progress
            if currentStep >= steps {
                self.panner.outputVolume = target
                t.invalidate()
                self.fadeTimer = nil
                completion?()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        fadeTimer = timer
    }
}
