//
//  StandbyToolBar.swift
//  NatureSound
//
//  Created by egbert on 2026/7/11.
//

import SwiftUI

// MARK: - 工具栏
struct StandbyToolBar: View {
    let showMixer: Bool
    let showTimer: Bool
    let showClock: Bool
    let showScene: Bool
    let timerIsActive: Bool
    let audioManager: AudioManager

    let onToggleMixer: () -> Void
    let onToggleTimer: () -> Void
    let onToggleClock: () -> Void
    let onToggleScene: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            toolBtn(icon: "slider.horizontal.3", label: "混音器", on: showMixer, color: Color(hex: "667eea"), action: onToggleMixer)
            toolBtn(icon: "timer", label: "定时", on: showTimer || timerIsActive, color: timerIsActive ? Color(hex: "FF6B6B") : Color(hex: "667eea"), action: onToggleTimer)
            toolBtn(icon: "clock", label: "时钟", on: showClock, color: Color(hex: "667eea"), action: onToggleClock)
            toolBtn(icon: "star", label: "场景", on: showScene, color: Color(hex: "FFD54F"), action: onToggleScene)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .background(PanelBackground())
    }

    private func toolBtn(icon: String, label: String, on: Bool, color: Color, action: @escaping () -> Void) -> some View {
        Button { Haptics.light(); action() } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .symbolRenderingMode(.monochrome)
                    .font(.system(size: 15))
                    .foregroundStyle(on ? color : Color.white.opacity(0.4))
                    .frame(width: 32, height: 32)
                    .background(
                        Circle().fill(on ? color.opacity(0.12) : Color.clear)
                    )
                Text(label)
                    .font(.system(size: 9, weight: on ? .semibold : .medium))
                    .foregroundStyle(on ? color.opacity(0.8) : Color.white.opacity(0.3))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}
