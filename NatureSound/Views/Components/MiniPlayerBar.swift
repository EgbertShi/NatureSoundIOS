//
//  MiniPlayerBar.swift
//  NatureSound
//
//  Created by egbert on 2026/7/1.
//

import SwiftUI

// MARK: - 底部迷你播放条
struct MiniPlayerBar: View {
    let audioManager: AudioManager
    let timerManager: TimerManager
    @State private var animatePulse = false

    var body: some View {
        HStack(spacing: 12) {
            // 声音图标堆叠
            HStack(spacing: -8) {
                ForEach(audioManager.activePlayers.prefix(3)) { player in
                    ZStack {
                        Circle().fill(player.sound.color.opacity(0.8)).frame(width: 32, height: 32)
                        Image(systemName: player.sound.icon)
                            .font(.system(size: 13))
                            .foregroundStyle(.white)
                    }
                    .overlay(Circle().stroke(Color(hex: "1A1A2E"), lineWidth: 2))
                    .scaleEffect(animatePulse ? 1.05 : 1.0)
                }
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) { animatePulse = true }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("\(audioManager.activeCount) 种声音混合中")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.9))
                if timerManager.isActive {
                    Text(timerManager.displayTime + " 后停止")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color(hex: "FF6B6B").opacity(0.8))
                } else {
                    Text("点击展开播放器")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.35))
                }
            }

            Spacer()

            Image(systemName: "chevron.up")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.4))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.1), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.3), radius: 20, y: -5)
        )
        .environment(\.colorScheme, .dark)
    }
}
