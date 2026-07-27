//
//  AppLogger.swift
//  NatureSound
//
//  Created by egbert on 2026/7/25.
//

import Foundation
import os

// MARK: - 应用统一日志工具

/// 基于 `os.Logger` 的轻量日志封装，按子系统/分类过滤。
/// 在 Console.app 或 Xcode 控制台可通过 `subsystem: com.egbert.NatureSound` 过滤。
enum AppLogger {
    private static let subsystem = "com.egbert.NatureSound"

    // MARK: 各模块 Logger 实例

    static let weather        = Logger(subsystem: subsystem, category: "Weather")
    static let audio          = Logger(subsystem: subsystem, category: "Audio")
    static let video          = Logger(subsystem: subsystem, category: "Video")
    static let timer          = Logger(subsystem: subsystem, category: "Timer")
    static let scene          = Logger(subsystem: subsystem, category: "Scene")
    static let liveActivity   = Logger(subsystem: subsystem, category: "LiveActivity")
    static let general        = Logger(subsystem: subsystem, category: "General")
}
