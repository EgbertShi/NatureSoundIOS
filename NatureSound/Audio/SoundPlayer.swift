//
//  SoundPlayer.swift
//  NatureSound
//
//  Created by egbert on 2026/7/1.
//

import AVFoundation
import SwiftUI

private let renderQueue = DispatchQueue(label: "com.naturevoice.render", qos: .userInitiated)

// MARK: - 流水线 Buffer 缓存
/// 播放当前 buffer 的同时，后台预渲染下一份，内存占用最小。
private final class BufferPipeline {
    static let shared = BufferPipeline()
    private let lock = NSLock()
    private var nextBuffer: [String: AVAudioPCMBuffer] = [:]
    private var rendering: Set<String> = []

    func take(_ soundID: String) -> AVAudioPCMBuffer? {
        lock.lock(); defer { lock.unlock() }
        return nextBuffer.removeValue(forKey: soundID)
    }

    func store(_ soundID: String, buffer: AVAudioPCMBuffer) {
        lock.lock(); defer { lock.unlock() }
        nextBuffer[soundID] = buffer
        rendering.remove(soundID)
    }

    func markRendering(_ soundID: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard !rendering.contains(soundID) else { return false }
        rendering.insert(soundID)
        return true
    }

    func clear(_ soundID: String) {
        lock.lock(); defer { lock.unlock() }
        nextBuffer.removeValue(forKey: soundID)
        rendering.remove(soundID)
    }

    func clearAll() {
        lock.lock(); defer { lock.unlock() }
        nextBuffer.removeAll()
        rendering.removeAll()
    }
}

// MARK: - 单个声音播放器
@Observable
final class SoundPlayer: Identifiable {
    let id: String
    let sound: SoundItem
    var volume: Float = 0.7
    var isPlaying: Bool = false

    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var buffer: AVAudioPCMBuffer?

    private static let sr: Double = 44100
    private static let dur: Double = 30.0

    init(sound: SoundItem) { self.id = sound.id; self.sound = sound }

    // MARK: - 播放控制

    func start(effectiveVolume: Float? = nil) {
        guard !isPlaying else { return }
        AudioSessionConfig.configure()
        isPlaying = true

        let vol = effectiveVolume ?? self.volume
        let snd = self.sound

        if let ready = BufferPipeline.shared.take(snd.id) {
            startPlayback(buffer: ready, volume: vol)
            Self.prerenderNext(for: snd)
            return
        }

        renderQueue.async { [weak self] in
            guard let buf = Self.renderNewBuffer(for: snd) else {
                DispatchQueue.main.async { self?.isPlaying = false }
                return
            }
            DispatchQueue.main.async {
                guard let self = self, self.isPlaying else { return }
                self.startPlayback(buffer: buf, volume: vol)
                Self.prerenderNext(for: snd)
            }
        }
    }

    func resumeIfNeeded() {
        guard isPlaying else { return }
        if let engine = audioEngine, engine.isRunning,
           let player = playerNode, player.isPlaying { return }
        AudioSessionConfig.configure()
        if let buf = buffer {
            playerNode?.stop()
            audioEngine?.stop()
            startPlayback(buffer: buf, volume: volume)
        }
    }

    func stop() {
        guard isPlaying else { return }
        isPlaying = false
        if let engine = audioEngine {
            let node = playerNode
            fadeVolume(to: 0, duration: 0.5) { [weak self] in
                node?.stop()
                engine.stop()
                self?.audioEngine = nil
                self?.playerNode = nil
                self?.buffer = nil
            }
        } else {
            playerNode?.stop()
            audioEngine?.stop()
            audioEngine = nil; playerNode = nil; buffer = nil
        }
    }

    func updateVolume(_ v: Float) {
        audioEngine?.mainMixerNode.outputVolume = v
    }

    // MARK: - 内部实现

    private static func prerenderNext(for snd: SoundItem) {
        guard BufferPipeline.shared.markRendering(snd.id) else { return }
        renderQueue.async {
            if let buf = renderNewBuffer(for: snd) {
                BufferPipeline.shared.store(snd.id, buffer: buf)
            }
        }
    }

    private static func renderNewBuffer(for snd: SoundItem) -> AVAudioPCMBuffer? {
        let n = AVAudioFrameCount(sr * dur)
        guard let fmt = AVAudioFormat(standardFormatWithSampleRate: sr, channels: 2),
              let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: n) else { return nil }
        buf.frameLength = n
        AudioSynthesis.render(sound: snd, into: buf, sampleRate: sr)
        return buf
    }

    private func startPlayback(buffer buf: AVAudioPCMBuffer, volume vol: Float) {
        guard let fmt = AVAudioFormat(standardFormatWithSampleRate: Self.sr, channels: 2) else { return }
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: fmt)
        engine.mainMixerNode.outputVolume = 0
        do {
            try engine.start()
            player.scheduleBuffer(buf, at: nil, options: .loops)
            player.play()
            audioEngine = engine
            playerNode = player
            buffer = buf
            fadeVolume(to: vol, duration: 1.5)
        } catch {
            print("引擎启动失败: \(error)")
            isPlaying = false
        }
    }

    private func fadeVolume(to target: Float, duration: Double, completion: (() -> Void)? = nil) {
        guard let engine = audioEngine else { completion?(); return }
        let current = engine.mainMixerNode.outputVolume
        let steps = max(1, Int(duration * 30))
        let stepDelta = (target - current) / Float(steps)
        var step = 0
        Timer.scheduledTimer(withTimeInterval: duration / Double(steps), repeats: true) { timer in
            step += 1
            if step >= steps {
                engine.mainMixerNode.outputVolume = target
                timer.invalidate()
                completion?()
            } else {
                engine.mainMixerNode.outputVolume = current + stepDelta * Float(step)
            }
        }
    }
}
