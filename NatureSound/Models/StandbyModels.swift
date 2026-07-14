//
//  StandbyModels.swift
//  NatureSound
//
//  Created by egbert on 2026/7/11.
//

import SwiftUI

// MARK: - 待机模式
enum StandbyMode {
    case immersive
    case timer
}

// MARK: - 呼吸光晕速度
enum BreathingSpeed: String, CaseIterable {
    case off = "关闭"
    case slow = "慢速"
    case normal = "正常"
    case fast = "快速"

    var duration: Double {
        switch self {
        case .off:    return .infinity
        case .slow:   return 6.0
        case .normal: return 4.0
        case .fast:   return 2.5
        }
    }
    var scale: CGFloat { self == .off ? 1.0 : 1.15 }
}

// MARK: - 时钟样式
enum ClockStyle: String, CaseIterable {
    case digital  = "数字"
    case dial     = "表盘"
    case minimal  = "极简"
    case split    = "分体"

    var icon: String {
        switch self {
        case .digital:  return "textformat.abc.dottedunderline"
        case .dial:     return "clock.fill"
        case .minimal:  return "textformat.size"
        case .split:    return "rectangle.split.2x1"
        }
    }
}

// MARK: - 自动隐藏时长
enum AutoHideDuration: String, CaseIterable {
    case three = "3秒"
    case five  = "5秒"
    case ten   = "10秒"
    case never = "不隐藏"

    var seconds: Double? {
        switch self {
        case .three: return 3
        case .five:  return 5
        case .ten:   return 10
        case .never: return nil
        }
    }
}
