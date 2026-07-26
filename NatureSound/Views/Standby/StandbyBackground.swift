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

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color(hex: "080812").opacity(0.95), Color.black],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            // 声音色彩光晕（静态）
            ForEach(Array(activePlayers.prefix(3).enumerated()), id: \.offset) { idx, player in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [player.sound.color.opacity(0.1), player.sound.color.opacity(0.03), .clear],
                            center: .center, startRadius: 0, endRadius: 120
                        )
                    )
                    .frame(width: 260, height: 260)
                    .blur(radius: 40)
                    .offset(x: CGFloat(idx - 1) * 90, y: CGFloat(idx - 1) * 50)
                    .opacity(0.7)
            }

            // 主色调光晕
            Circle()
                .fill(
                    RadialGradient(
                        colors: [primaryColor.opacity(0.05), .clear],
                        center: .center, startRadius: 0, endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
                .opacity(0.5)

            starField
        }
    }

    private var starField: some View {
        Canvas { context, size in
            let stars: [(x: Double, y: Double, r: Double, a: Double)] = [
                (0.1, 0.15, 1.0, 0.3), (0.25, 0.08, 0.8, 0.2),
                (0.45, 0.12, 1.2, 0.35), (0.65, 0.06, 0.6, 0.15),
                (0.82, 0.18, 1.0, 0.25), (0.93, 0.10, 0.7, 0.2),
                (0.08, 0.85, 0.9, 0.22), (0.22, 0.92, 1.1, 0.3),
                (0.38, 0.88, 0.7, 0.18), (0.55, 0.94, 0.8, 0.2),
                (0.72, 0.86, 1.0, 0.28), (0.88, 0.91, 0.6, 0.15),
                (0.15, 0.45, 0.5, 0.1), (0.85, 0.50, 0.5, 0.1),
            ]
            for star in stars {
                let pt = CGPoint(x: size.width * star.x, y: size.height * star.y)
                context.opacity = star.a
                context.fill(
                    Circle().path(in: CGRect(x: pt.x - star.r, y: pt.y - star.r, width: star.r * 2, height: star.r * 2)),
                    with: .color(.white)
                )
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
