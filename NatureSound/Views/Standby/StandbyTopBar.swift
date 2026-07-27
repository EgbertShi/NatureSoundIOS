//
//  StandbyTopBar.swift
//  NatureSound
//
//  Created by egbert on 2026/7/11.
//

import SwiftUI

// MARK: - 顶部栏
struct StandbyTopBar: View {
    let timerManager: TimerManager
    let isLandscape: Bool
    let onExit: () -> Void
    let onStopAll: () -> Void
    let onAddTime: (Int) -> Void
    let onToggleOrientation: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button { Haptics.light(); onExit() } label: {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.left").font(.system(size: 12, weight: .bold))
                    Text("退出").font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(Color.white.opacity(0.6))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Capsule().fill(.ultraThinMaterial).overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 0.5)))
            }
            .buttonStyle(.plain)

            if isLandscape {
                Spacer().frame(width: 200)
            } else {
                Spacer()
            }

            Button { Haptics.light(); onToggleOrientation() } label: {
                Image(systemName: isLandscape ? "rectangle.portrait" : "rectangle.landscape.rotate")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.6))
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(.ultraThinMaterial).overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 0.5)))
            }
            .buttonStyle(.plain)

            Button { onStopAll() } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.65))
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.red.opacity(0.2)).overlay(Circle().stroke(Color.red.opacity(0.15), lineWidth: 0.5)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}
