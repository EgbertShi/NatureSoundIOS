//
//  StandbyClockStylePanel.swift
//  NatureSound
//
//  Created by egbert on 2026/7/11.
//

import SwiftUI

// MARK: - 时钟样式面板
struct StandbyClockPanel: View {
    let clockStyle: ClockStyle
    let use24Hour: Bool
    let showSeconds: Bool
    let showDate: Bool
    let clockScale: Double
    let isLandscape: Bool

    let onSelectClockStyle: (ClockStyle) -> Void
    let onToggle24Hour: (Bool) -> Void
    let onToggleSeconds: (Bool) -> Void
    let onToggleDate: (Bool) -> Void
    let onSelectClockScale: (Double) -> Void
    let onInteract: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "clock").font(.system(size: 12)).foregroundStyle(Color.white.opacity(0.4))
                Text("时钟样式").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.white.opacity(0.6))
                Spacer()
            }

            // 样式选择
            HStack(spacing: 8) {
                ForEach(ClockStyle.allCases, id: \.self) { style in
                    clockStyleCard(style)
                }
            }

            // 显示选项 + 大小选项
            HStack(spacing: 4) {
                Text("显示").font(.system(size: 10, weight: .medium)).foregroundStyle(Color.white.opacity(0.3))
                chip("24h", isOn: use24Hour) { onToggle24Hour(!use24Hour); onInteract() }
                chip("秒", isOn: showSeconds) { onToggleSeconds(!showSeconds); onInteract() }
                chip("日期", isOn: showDate) { onToggleDate(!showDate); onInteract() }
                Spacer(minLength: 4)
                Text("大小").font(.system(size: 10, weight: .medium)).foregroundStyle(Color.white.opacity(0.3))
                ForEach([("小", 0.8), ("中", 1.0), ("大", 1.3)], id: \.0) { label, scale in
                    chip(label, isOn: abs(clockScale - scale) < 0.05) { onSelectClockScale(scale); onInteract() }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(PanelBackground())
    }

    private func clockStyleCard(_ style: ClockStyle) -> some View {
        let selected = clockStyle == style
        return Button {
            Haptics.light()
            withAnimation(.spring(response: 0.3)) { onSelectClockStyle(style) }
            onInteract()
        } label: {
            VStack(spacing: 5) {
                Image(systemName: style.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(selected ? Color(hex: "667eea") : Color.white.opacity(0.35))
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(selected ? Color(hex: "667eea").opacity(0.15) : Color.white.opacity(0.04))
                    )
                Text(style.rawValue)
                    .font(.system(size: 10, weight: selected ? .bold : .medium))
                    .foregroundStyle(selected ? Color.white.opacity(0.85) : Color.white.opacity(0.35))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selected ? Color(hex: "667eea").opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func chip(_ label: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button { Haptics.light(); action() } label: {
            Text(label)
                .font(.system(size: 10, weight: isOn ? .bold : .medium))
                .foregroundStyle(isOn ? Color(hex: "667eea") : Color.white.opacity(0.35))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(isOn ? Color(hex: "667eea").opacity(0.15) : Color.white.opacity(0.04))
                        .overlay(Capsule().stroke(isOn ? Color(hex: "667eea").opacity(0.3) : Color.white.opacity(0.06), lineWidth: 0.5))
                )
        }
        .buttonStyle(.plain)
    }
}
