//
//  FocusMode.swift
//  NatureSound
//
//  Created by egbert on 2026/7/30.
//

import SwiftUI

// MARK: - 专注模式

/// 首页四大模式入口：入睡、专注、放松、冥想。
/// 每种模式关联默认定时时长、推荐场景标签、是否需要唤醒等属性。
enum FocusMode: String, CaseIterable, Identifiable {
    case sleep      = "入睡"
    case focus      = "专注"
    case relax      = "放松"
    case meditation = "冥想"

    var id: String { rawValue }

    /// 模式显示名称
    var displayName: String { rawValue }

    /// 模式图标
    var icon: String {
        switch self {
        case .sleep:      return "moon.zzz.fill"
        case .focus:      return "brain.head.profile.fill"
        case .relax:      return "leaf.fill"
        case .meditation: return "figure.mind.and.body"
        }
    }

    /// 模式主题色
    var themeColor: Color {
        switch self {
        case .sleep:      return Color(hex: "6366F1")
        case .focus:      return Color(hex: "F59E0B")
        case .relax:      return Color(hex: "10B981")
        case .meditation: return Color(hex: "8B5CF6")
        }
    }

    /// 模式副标题描述
    var subtitle: String {
        switch self {
        case .sleep:      return "伴你安然入梦"
        case .focus:      return "沉浸高效时刻"
        case .relax:      return "释放身心压力"
        case .meditation: return "内观宁静之境"
        }
    }

    /// 对应的场景标签，用于筛选推荐场景
    var matchingTag: SceneTag {
        switch self {
        case .sleep:      return .sleep
        case .focus:      return .focus
        case .relax:      return .relax
        case .meditation: return .meditation
        }
    }

    /// 默认定时时长（分钟）
    var defaultMinutes: Int {
        switch self {
        case .sleep:      return 30
        case .focus:      return 45
        case .relax:      return 20
        case .meditation: return 15
        }
    }

    /// 定时结束后是否需要唤醒确认（入睡模式不需要）
    var needsWakeUp: Bool {
        switch self {
        case .sleep:      return false
        case .focus, .relax, .meditation: return true
        }
    }

    /// 可选定时时长范围（分钟）
    static let timerRange: ClosedRange<Int> = 5...120

    /// 快捷时长按钮（分钟）
    var quickDurations: [Int] {
        switch self {
        case .sleep:      return [15, 30, 45, 60, 90]
        case .focus:      return [25, 45, 60, 90, 120]
        case .relax:      return [10, 15, 20, 30, 45]
        case .meditation: return [5, 10, 15, 20, 30]
        }
    }
}

// MARK: - 唤醒铃声

/// 唤醒铃声配置：定时结束后（非入睡模式）播放的提示音。
/// 使用项目中已有的禅意类 .m4a 音频文件作为唤醒音源。
struct WakeUpTone: Identifiable, Equatable {
    let id: String
    let name: String
    let fileName: String
    let category: String

    /// 预置的三个唤醒铃声
    static let allTones: [WakeUpTone] = [
        WakeUpTone(id: "chime",       name: "风铃叮当", fileName: "风铃叮当",   category: "禅意"),
        WakeUpTone(id: "temple_bell", name: "古寺钟声", fileName: "古寺钟声",   category: "禅意"),
        WakeUpTone(id: "zen_bell",    name: "禅意编钟", fileName: "禅意编钟",   category: "禅意"),
    ]

    /// 默认唤醒铃声
    static let defaultTone = allTones[0]

    /// 根据 ID 查找铃声
    static func tone(for id: String) -> WakeUpTone {
        allTones.first { $0.id == id } ?? defaultTone
    }
}
