//
//  TimerButton.swift
//  NatureSound
//
//  Created by egbert on 2026/7/1.
//

import SwiftUI

// MARK: - 定时按钮
struct TimerButton: View {
    let minutes: Int
    let isSelected: Bool
    let onTap: () -> Void

    private var displayText: String {
        if minutes >= 60 {
            return minutes % 60 == 0 ? "\(minutes / 60)小时" : "\(minutes / 60)小时\(minutes % 60)分"
        }
        return "\(minutes)分钟"
    }

    var body: some View {
        Button(action: onTap) {
            Text(displayText)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isSelected ? Color.white.opacity(0.95) : Color.white.opacity(0.5))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? Color(hex: "667eea").opacity(0.25) : Color.white.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isSelected ? Color(hex: "667eea").opacity(0.5) : Color.white.opacity(0.06), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }
}
