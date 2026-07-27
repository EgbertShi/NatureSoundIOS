//
//  AudioUtils.swift
//  NatureSound
//
//  Created by egbert on 2026/7/1.
//

import AVFoundation

// MARK: - 音频会话配置
enum AudioSessionConfig {
    /// 配置音频会话，确保后台持续播放。
    /// 使用 .playback category，让系统将本 app 视为主音频源，
    /// 退后台时保持 audio session 活跃（配合 UIBackgroundModes audio）。
    static func configure() {
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true, options: [])
        } catch {
            print("[AudioSession] 配置失败: \(error)")
        }
        #endif
    }
}

// MARK: - 高质量随机数 (SplitMix64)
struct RNG {
    var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0xDEADBEEF : seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
    mutating func f01() -> Float { Float(next() >> 40) / Float(1 << 24) }
    mutating func signed() -> Float { f01() * 2.0 - 1.0 }
    mutating func range(_ lo: Double, _ hi: Double) -> Double { lo + Double(f01()) * (hi - lo) }
}

// MARK: - 一阶低通滤波器
struct LP1 {
    var y: Float = 0
    var a: Float
    init(hz: Float, sr: Float) { a = 1.0 - Float(exp(-2.0 * .pi * Double(hz) / Double(sr))) }
    mutating func tick(_ x: Float) -> Float { y += a * (x - y); return y }
}

// MARK: - Perlin 噪声（一维）
struct PerlinLFO {
    private var grad: [Float]
    private let tableSize: Int

    init(rng: inout RNG, size: Int = 256) {
        tableSize = size
        grad = (0..<size).map { _ in rng.signed() }
    }

    private func fade(_ t: Float) -> Float { t * t * t * (t * (t * 6 - 15) + 10) }
    private func lerp(_ a: Float, _ b: Float, _ t: Float) -> Float { a + t * (b - a) }

    func sample(t: Double, speed: Double = 1.0) -> Float {
        let p = Float(t * speed)
        let i = Int(floor(p)) & (tableSize - 1)
        let j = (i + 1) & (tableSize - 1)
        let frac = p - floor(p)
        return lerp(grad[i] * frac, grad[j] * (frac - 1.0), fade(frac))
    }
}
