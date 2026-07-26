//
//  Theme.swift
//  NatureSound
//
//  Created by egbert on 2026/7/1.
//

import SwiftUI

// MARK: - 主题色彩系统
enum Theme {
    // MARK: 品牌色
    static let accent      = Color(hex: "5B6ABF")
    static let accentEnd   = Color(hex: "7B6BB5")
    static let teal        = Color(hex: "4A9E9A")
    static let danger      = Color(hex: "E07065")
    static let gold        = Color(hex: "D4A64A")
    static let success     = Color(hex: "5DAE7A")

    static let accentGradient = LinearGradient(
        colors: [accent, accentEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: 背景色
    static func backgroundColors(_ scheme: ColorScheme) -> [Color] {
        scheme == .dark
            ? [Color(hex: "0E1117"), Color(hex: "141820"), Color(hex: "111520")]
            : [Color(hex: "F8F9FB"), Color(hex: "F5F6F8"), Color(hex: "F2F3F6")]
    }

    static func backgroundGradient(_ scheme: ColorScheme) -> LinearGradient {
        LinearGradient(
            colors: backgroundColors(scheme),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: 卡片
    static func cardFill(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "1C1C1E") : Color.white
    }

    static func cardBorder(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.06)
    }

    // MARK: 文字
    static func textPrimary(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.9) : Color.black.opacity(0.9)
    }

    static func textSecondary(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.6) : Color.black.opacity(0.6)
    }

    static func textTertiary(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.35) : Color.black.opacity(0.35)
    }

    // MARK: 图标
    static func iconDefault(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.5) : Color.black.opacity(0.5)
    }

    // MARK: 选中 / 非选中状态
    static func selectedFill(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? accent.opacity(0.15) : accent.opacity(0.1)
    }

    static func selectedBorder(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? accent.opacity(0.3) : accent.opacity(0.25)
    }

    static func inactiveFill(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.03)
    }

    static func inactiveIconForeground(_ scheme: ColorScheme, soundColor: Color) -> Color {
        scheme == .dark ? soundColor.opacity(0.5) : soundColor.opacity(0.6)
    }

    static func inactiveCircleFill(_ scheme: ColorScheme, soundColor: Color) -> Color {
        scheme == .dark ? soundColor.opacity(0.08) : soundColor.opacity(0.1)
    }

    // MARK: 分隔线 & 面板
    static func separator(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.06)
    }

    static func sheetFill(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "1A1E28") : Color.white
    }

    static func stackBorder(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.08)
    }

    static func trackFill(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.08)
    }

    // MARK: 发光 & 渐变
    static func glowOpacity(_ scheme: ColorScheme) -> Double {
        scheme == .dark ? 0.06 : 0.03
    }

    static func titleGradient(_ scheme: ColorScheme) -> LinearGradient {
        LinearGradient(
            colors: scheme == .dark
                ? [Color.white, Color.white.opacity(0.7)]
                : [Color.black, Color.black.opacity(0.7)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    // MARK: 设置 & 标签栏
    static func settingsBg(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "0E1117") : Color(hex: "F5F6F8")
    }

    static func tabBarFill(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "1C1C1E") : Color.white
    }

    // MARK: 灰度辅助
    static let gray1 = Color(hex: "6B6B6B")
    static let gray2 = Color(hex: "9A9A9A")
    static let gray3 = Color(hex: "888888")
}
