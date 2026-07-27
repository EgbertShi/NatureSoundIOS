//
//  StandbyTimerPanel.swift
//  NatureSound
//
//  Created by egbert on 2026/7/11.
//

import SwiftUI

// MARK: - 定时器面板
struct StandbyTimerPanel: View {
    let timerManager: TimerManager
    let isLandscape: Bool
    let onStartTimer: (Int) -> Void
    let onCancelTimer: () -> Void
    let onAddTime: (Int) -> Void
    let onInteract: () -> Void

    private let quickPresets: [Int] = [10, 15, 20, 30, 45, 60]
    private let morePresets: [Int] = [5, 90, 120]
    @State private var showMore = false

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "timer")
                    .font(.system(size: 12))
                    .foregroundStyle(timerManager.isActive ? Color(hex: "FF6B6B") : Color.white.opacity(0.4))
                Text("定时关闭")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.6))
                Spacer()
                if timerManager.isActive {
                    Text(timerManager.displayTime)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(hex: "FF6B6B").opacity(0.9))
                        .contentTransition(.numericText())
                }
            }

            if timerManager.isActive {
                timerActiveView
            } else {
                timerPresetGrid
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(
                    timerManager.isActive ? Color(hex: "FF6B6B").opacity(0.15) : Color.white.opacity(0.06),
                    lineWidth: 0.5
                ))
        )
        .animation(.spring(response: 0.35), value: timerManager.isActive)
        .animation(.spring(response: 0.3), value: showMore)
    }

    private var timerPresetGrid: some View {
        VStack(spacing: 6) {
            let cols = isLandscape
                ? Array(repeating: GridItem(.flexible(), spacing: 6), count: 6)
                : Array(repeating: GridItem(.flexible(), spacing: 6), count: 3)
            LazyVGrid(columns: cols, spacing: 6) {
                ForEach(quickPresets, id: \.self) { m in presetBtn(m) }
            }
            if !showMore {
                Button {
                    Haptics.light(); showMore = true
                } label: {
                    HStack(spacing: 3) {
                        Text("更多").font(.system(size: 10, weight: .medium))
                        Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold))
                    }
                    .foregroundStyle(Color.white.opacity(0.3))
                    .padding(.top, 2)
                }
                .buttonStyle(.plain)
            } else {
                HStack(spacing: 6) {
                    ForEach(morePresets, id: \.self) { m in presetBtn(m) }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private func presetBtn(_ minutes: Int) -> some View {
        Button {
            Haptics.medium(); onStartTimer(minutes); onInteract()
        } label: {
            VStack(spacing: 1) {
                Text("\(minutes)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.8))
                Text("分钟")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.3))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.05))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.08), lineWidth: 0.5))
            )
        }
        .buttonStyle(.plain)
    }

    private var timerActiveView: some View {
        VStack(spacing: 10) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.08))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(LinearGradient(colors: [Color(hex: "FF6B6B"), Color(hex: "FF8E53")], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * timerManager.progress)
                        .animation(.linear(duration: 1), value: timerManager.progress)
                }
            }
            .frame(height: 3)

            HStack(spacing: 8) {
                ForEach([5, 10], id: \.self) { m in
                    Button {
                        Haptics.medium(); onAddTime(m); onInteract()
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "plus").font(.system(size: 9, weight: .bold))
                            Text("\(m)分钟").font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(Color(hex: "FF8E53"))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(Color(hex: "FF8E53").opacity(0.12))
                                .overlay(Capsule().stroke(Color(hex: "FF8E53").opacity(0.2), lineWidth: 0.5))
                        )
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Button {
                    Haptics.light(); onCancelTimer(); onInteract()
                } label: {
                    Text("取消").font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.5))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.white.opacity(0.06)))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
