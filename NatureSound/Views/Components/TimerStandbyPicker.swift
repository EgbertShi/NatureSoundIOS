//
//  TimerStandbyPicker.swift
//  NatureSound
//
//  Created by egbert on 2026/7/11.
//

import SwiftUI

// MARK: - 定时模式选择弹窗
struct TimerStandbyPicker: View {
    let timerManager: TimerManager
    let audioManager: AudioManager
    @Binding var isPresented: Bool
    @Binding var showStandby: Bool
    var onPlayerDismiss: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "667eea"), Color(hex: "764ba2")],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                Text("定时待机")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.9))
                Text("选择时长后进入待机，到时间声音自动停止")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.white.opacity(0.4))
                    .multilineTextAlignment(.center)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(TimerManager.presetMinutes, id: \.self) { minutes in
                    TimerButton(
                        minutes: minutes,
                        isSelected: timerManager.selectedMinutes == minutes
                    ) { timerManager.selectedMinutes = minutes }
                }
            }
            .padding(.horizontal, 24)

            Button {
                timerManager.start {
                    audioManager.stopAll()
                    showStandby = false
                }
                isPresented = false
                onPlayerDismiss?()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { showStandby = true }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill").font(.system(size: 14))
                    Text("开始待机 \(timerManager.selectedMinutes) 分钟")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(LinearGradient(colors: [Color(hex: "667eea"), Color(hex: "764ba2")], startPoint: .leading, endPoint: .trailing))
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)

            Button("取消") { isPresented = false }
                .font(.system(size: 14))
                .foregroundStyle(Color.white.opacity(0.4))
        }
        .padding(.vertical, 28)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(hex: "1A1A2E"))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.08), lineWidth: 0.5))
        )
    }
}
