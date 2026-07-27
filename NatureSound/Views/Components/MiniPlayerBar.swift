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
                    .overlay(Circle().stroke(Theme.tabBarFill(.light), lineWidth: 2))
                    .scaleEffect(animatePulse ? 1.05 : 1.0)
                }
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) { animatePulse = true }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("\(audioManager.activeCount) 种声音混合中")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary(.light))
                if audioManager.isPaused {
                    Text("已暂停，点击继续")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.textTertiary(.light))
                } else if timerManager.isActive {
                    Text(timerManager.displayTime + " 后停止")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(Theme.danger.opacity(0.8))
                } else {
                    Text("点击进入沉浸模式")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.textTertiary(.light))
                }
            }

            Spacer()

            // 停止 / 播放按钮
            Button {
                Haptics.light()
                if audioManager.isPaused {
                    audioManager.playAll()
                } else {
                    audioManager.stopAll()
                }
            } label: {
                Image(systemName: audioManager.isPaused ? "play.fill" : "stop.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(audioManager.isPaused ? Theme.accent : Theme.danger)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill((audioManager.isPaused ? Theme.accent : Theme.danger).opacity(0.12)))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)

            Image(systemName: "chevron.up")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.textTertiary(.light))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.cardBorder(.light), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.1), radius: 20, y: -5)
        )
    }
}
