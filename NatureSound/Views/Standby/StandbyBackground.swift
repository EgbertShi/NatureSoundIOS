//
//  StandbyBackground.swift
//  NatureSound
//
//  Created by egbert on 2026/7/11.
//

import SwiftUI

// MARK: - 待机背景
struct StandbyBackground: View {
    let primaryColor: Color
    let activePlayers: [SoundPlayer]

    // MARK: 呼吸动画状态
    @State private var breathePhase: Bool = false
    @State private var twinklePhase: Bool = false
    @State private var auroraPhase: Bool = false

    /// 从活跃声音中提取最多 3 种颜色，无声音时使用主色调的变体
    private var glowColors: [Color] {
        if activePlayers.isEmpty {
            return [primaryColor, primaryColor.opacity(0.7), Color(hex: "764ba2")]
        }
        return activePlayers.prefix(3).map { $0.sound.color }
    }

    var body: some View {
        ZStack {
            // 基础渐变底色
            baseGradient

            // 极光光带
            auroraLayer

            // 声音色彩光晕（带呼吸动画）
            glowOrbs

            // 主色调光晕
            centralGlow

            // 星空
            starField

            // 顶部微弱的大气散射
            atmosphericHaze
        }
        .onAppear { startAnimations() }
    }

    // MARK: - 基础渐变

    private var baseGradient: some View {
        LinearGradient(
            colors: [
                Color.black,
                Color(hex: "050510"),
                Color(hex: "080818").opacity(0.95),
                Color(hex: "050510"),
                Color.black
            ],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - 极光光带

    private var auroraLayer: some View {
        ZStack {
            // 上方极光
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [
                            glowColors[0].opacity(0.06),
                            glowColors.count > 1 ? glowColors[1].opacity(0.03) : primaryColor.opacity(0.03),
                            .clear
                        ],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .frame(width: 500, height: 120)
                .blur(radius: 60)
                .offset(x: auroraPhase ? 30 : -30, y: -200)
                .opacity(0.8)

            // 下方极光
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [
                            .clear,
                            glowColors.last?.opacity(0.04) ?? primaryColor.opacity(0.04),
                            primaryColor.opacity(0.06),
                            .clear
                        ],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .frame(width: 450, height: 100)
                .blur(radius: 50)
                .offset(x: auroraPhase ? -20 : 20, y: 240)
                .opacity(0.7)
        }
        .animation(.easeInOut(duration: 12).repeatForever(autoreverses: true), value: auroraPhase)
    }

    // MARK: - 声音色彩光晕

    private var glowOrbs: some View {
        ZStack {
            ForEach(Array(glowColors.enumerated()), id: \.offset) { idx, color in
                let positions: [(x: CGFloat, y: CGFloat)] = [
                    (-60, -80), (70, 40), (-30, 120)
                ]
                let pos = positions[idx % positions.count]
                let scale: CGFloat = breathePhase ? 1.15 : 0.85
                let opacity: Double = breathePhase ? 0.22 : 0.10

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [color.opacity(0.25), color.opacity(0.08), .clear],
                            center: .center, startRadius: 0, endRadius: 140
                        )
                    )
                    .frame(width: 280, height: 280)
                    .blur(radius: 50)
                    .scaleEffect(scale)
                    .opacity(opacity)
                    .offset(x: pos.x, y: pos.y)
                    .animation(
                        .easeInOut(duration: Double(4 + idx * 2))
                            .repeatForever(autoreverses: true)
                            .delay(Double(idx) * 1.2),
                        value: breathePhase
                    )
            }
        }
    }

    // MARK: - 中心光晕

    private var centralGlow: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [primaryColor.opacity(breathePhase ? 0.08 : 0.03), .clear],
                    center: .center, startRadius: 0, endRadius: 220
                )
            )
            .frame(width: 440, height: 440)
            .blur(radius: 20)
            .opacity(0.6)
            .animation(.easeInOut(duration: 6).repeatForever(autoreverses: true), value: breathePhase)
    }

    // MARK: - 星空

    private var starField: some View {
        Canvas { context, size in
            let stars: [(x: Double, y: Double, r: Double, a: Double, twinkle: Bool)] = [
                // 较亮的星星（会闪烁）
                (0.08, 0.10, 1.2, 0.45, true),
                (0.22, 0.06, 1.0, 0.35, true),
                (0.42, 0.14, 1.4, 0.50, true),
                (0.63, 0.04, 0.8, 0.30, false),
                (0.78, 0.16, 1.1, 0.40, true),
                (0.91, 0.08, 0.9, 0.28, false),
                (0.35, 0.25, 0.7, 0.20, false),
                (0.55, 0.22, 1.0, 0.32, true),
                // 中部稀疏的星星
                (0.12, 0.42, 0.6, 0.15, false),
                (0.88, 0.48, 0.7, 0.18, true),
                (0.50, 0.38, 0.5, 0.12, false),
                (0.30, 0.55, 0.8, 0.20, false),
                (0.70, 0.52, 0.6, 0.14, true),
                // 下部的星星
                (0.06, 0.82, 1.0, 0.30, true),
                (0.18, 0.90, 1.2, 0.38, false),
                (0.35, 0.86, 0.8, 0.22, true),
                (0.48, 0.93, 0.9, 0.25, false),
                (0.62, 0.88, 1.1, 0.35, true),
                (0.80, 0.84, 0.7, 0.20, false),
                (0.92, 0.92, 1.0, 0.30, true),
                // 额外散布
                (0.15, 0.70, 0.5, 0.12, false),
                (0.40, 0.68, 0.6, 0.15, true),
                (0.58, 0.75, 0.5, 0.10, false),
                (0.75, 0.72, 0.7, 0.18, false),
                (0.95, 0.65, 0.4, 0.10, false),
                (0.03, 0.30, 0.5, 0.10, false),
                (0.97, 0.35, 0.6, 0.12, false),
            ]
            for star in stars {
                let pt = CGPoint(x: size.width * star.x, y: size.height * star.y)
                let twinkleFactor: Double = (star.twinkle && twinklePhase) ? 0.6 : 1.0
                context.opacity = star.a * twinkleFactor
                context.fill(
                    Circle().path(in: CGRect(x: pt.x - star.r, y: pt.y - star.r, width: star.r * 2, height: star.r * 2)),
                    with: .color(.white)
                )
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: twinklePhase)
    }

    // MARK: - 大气散射

    private var atmosphericHaze: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [primaryColor.opacity(0.03), .clear],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 200)
            Spacer()
            LinearGradient(
                colors: [.clear, primaryColor.opacity(0.02)],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 150)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: - 动画启动

    private func startAnimations() {
        breathePhase = true
        twinklePhase = true
        auroraPhase = true
    }
}
