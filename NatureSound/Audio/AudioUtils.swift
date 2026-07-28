//
//  AudioUtils.swift
//  NatureSound
//
//  Created by egbert on 2026/7/1.
//

import AVFoundation
import os

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
            AppLogger.audio.error("音频会话配置失败: \(error.localizedDescription, privacy: .public)")
        }
        #endif
    }
}
