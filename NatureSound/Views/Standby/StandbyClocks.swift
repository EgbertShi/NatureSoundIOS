//
//  StandbyClocks.swift
//  NatureSound
//
//  Created by egbert on 2026/7/11.
//

import SwiftUI

// MARK: - 时钟时间格式化
struct ClockTimeFormatter {
    let use24Hour: Bool
    let showSeconds: Bool
    let showDate: Bool

    func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = use24Hour ? "HH:mm" : "h:mm"
        return f.string(from: date)
    }

    func amPM(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "a"
        return f.string(from: date)
    }

    func seconds(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "ss"
        return f.string(from: date)
    }

    func dateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "M月d日 EEEE"
        f.locale = Locale(identifier: "zh_CN")
        return f.string(from: date)
    }

    func hourString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = use24Hour ? "HH" : "h"
        return f.string(from: date)
    }

    func minuteString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "mm"
        return f.string(from: date)
    }
}

// MARK: - 时钟角度
struct ClockAngles {
    let calendar = Calendar.current

    func hour(_ date: Date) -> Angle {
        let h = calendar.component(.hour, from: date) % 12
        let m = calendar.component(.minute, from: date)
        return .degrees(Double(h) * 30 + Double(m) * 0.5)
    }

    func minute(_ date: Date) -> Angle {
        let m = calendar.component(.minute, from: date)
        let s = calendar.component(.second, from: date)
        return .degrees(Double(m) * 6 + Double(s) * 0.1)
    }

    func second(_ date: Date) -> Angle {
        .degrees(Double(calendar.component(.second, from: date)) * 6)
    }
}

// MARK: - 倒计时徽章
struct CountdownBadge: View {
    let timerManager: TimerManager

    var body: some View {
        if timerManager.isActive {
            HStack(spacing: 5) {
                Image(systemName: "timer").font(.system(size: 11))
                Text(timerManager.displayTime)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .contentTransition(.numericText())
            }
            .foregroundStyle(Color(hex: "FF6B6B").opacity(0.8))
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color(hex: "FF6B6B").opacity(0.1))
                    .overlay(Capsule().stroke(Color(hex: "FF6B6B").opacity(0.15), lineWidth: 0.5))
            )
            .padding(.top, 6)
        }
    }
}

// MARK: - 定时进度环
struct TimerRing: View {
    let timerManager: TimerManager

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.06), lineWidth: 2)
                .frame(width: 200, height: 200)
            Circle()
                .trim(from: 0, to: timerManager.progress)
                .stroke(
                    LinearGradient(colors: [Color(hex: "FF6B6B"), Color(hex: "FF8E53")], startPoint: .topLeading, endPoint: .bottomTrailing),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
                .frame(width: 200, height: 200)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: timerManager.progress)
        }
        .frame(width: 200, height: 200)
        .padding(.bottom, 4)
    }
}

// MARK: - 数字时钟
struct DigitalClock: View {
    let time: Date
    let formatter: ClockTimeFormatter
    let primaryColor: Color
    let timerManager: TimerManager

    @State private var glowPulse = false

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(formatter.timeString(time))
                    .font(.system(size: 78, weight: .bold, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [Color.white.opacity(0.95), Color.white.opacity(0.65)], startPoint: .top, endPoint: .bottom))
                    .contentTransition(.numericText())
                    .shadow(color: primaryColor.opacity(glowPulse ? 0.5 : 0.25), radius: glowPulse ? 30 : 18)
                    .animation(.easeInOut(duration: 4).repeatForever(autoreverses: true), value: glowPulse)
                if !formatter.use24Hour {
                    Text(formatter.amPM(time))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.4))
                        .padding(.bottom, 8)
                }
            }
            if formatter.showSeconds {
                Text(formatter.seconds(time))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(primaryColor.opacity(0.6))
                    .contentTransition(.numericText())
            }
            if formatter.showDate {
                Text(formatter.dateString(time))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.35))
                    .tracking(2)
                    .padding(.top, 2)
            }
            CountdownBadge(timerManager: timerManager)
        }
        .onAppear { glowPulse = true }
    }
}

// MARK: - 表盘时钟
struct DialClock: View {
    let time: Date
    let formatter: ClockTimeFormatter
    let primaryColor: Color
    let timerManager: TimerManager
    private let angles = ClockAngles()

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                // 表盘背景光晕
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [primaryColor.opacity(0.06), .clear],
                            center: .center, startRadius: 0, endRadius: 100
                        )
                    )
                    .frame(width: 200, height: 200)

                Circle().stroke(Color.white.opacity(0.1), lineWidth: 1).frame(width: 180, height: 180)

                ForEach(0..<12, id: \.self) { i in
                    Rectangle()
                        .fill(Color.white.opacity(i % 3 == 0 ? 0.35 : 0.12))
                        .frame(width: i % 3 == 0 ? 1.5 : 1, height: i % 3 == 0 ? 12 : 6)
                        .offset(y: -78)
                        .rotationEffect(.degrees(Double(i) * 30))
                }

                Rectangle().fill(Color.white.opacity(0.85)).frame(width: 3, height: 40).offset(y: -20).rotationEffect(angles.hour(time)).animation(.linear(duration: 0.5), value: time)
                Rectangle().fill(Color.white.opacity(0.65)).frame(width: 2, height: 58).offset(y: -29).rotationEffect(angles.minute(time)).animation(.linear(duration: 0.5), value: time)
                if formatter.showSeconds {
                    Rectangle().fill(primaryColor.opacity(0.8)).frame(width: 1, height: 66).offset(y: -33).rotationEffect(angles.second(time)).animation(.linear(duration: 0.5), value: time)
                        .shadow(color: primaryColor.opacity(0.5), radius: 4)
                }
                Circle().fill(primaryColor.opacity(0.9)).frame(width: 8, height: 8)
                    .shadow(color: primaryColor.opacity(0.5), radius: 6)
                Circle().fill(Color.black).frame(width: 3, height: 3)
            }
            .frame(width: 180, height: 180)

            HStack(spacing: 4) {
                Text(formatter.timeString(time))
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.7))
                    .contentTransition(.numericText())
                if !formatter.use24Hour {
                    Text(formatter.amPM(time)).font(.system(size: 11, weight: .medium)).foregroundStyle(Color.white.opacity(0.4))
                }
            }
            if formatter.showDate {
                Text(formatter.dateString(time))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.3))
                    .tracking(2)
            }
            CountdownBadge(timerManager: timerManager)
        }
    }
}

// MARK: - 极简时钟
struct MinimalClock: View {
    let time: Date
    let formatter: ClockTimeFormatter
    let primaryColor: Color
    let timerManager: TimerManager

    @State private var glowPulse = false

    var body: some View {
        VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(formatter.timeString(time))
                    .font(.system(size: 64, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .contentTransition(.numericText())
                    .shadow(color: primaryColor.opacity(glowPulse ? 0.35 : 0.15), radius: glowPulse ? 24 : 12)
                    .animation(.easeInOut(duration: 5).repeatForever(autoreverses: true), value: glowPulse)
                if !formatter.use24Hour {
                    Text(formatter.amPM(time)).font(.system(size: 14, weight: .medium)).foregroundStyle(Color.white.opacity(0.35)).padding(.bottom, 6)
                }
            }
            if formatter.showSeconds {
                HStack(spacing: 2) {
                    ForEach(Array(formatter.seconds(time).enumerated()), id: \.offset) { _, ch in
                        Text(String(ch))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(primaryColor.opacity(0.5))
                            .contentTransition(.numericText())
                    }
                }
                .padding(.top, 2)
            }
            if formatter.showDate {
                Text(formatter.dateString(time))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.3))
                    .tracking(2)
                    .padding(.top, 4)
            }
            CountdownBadge(timerManager: timerManager)
        }
        .onAppear { glowPulse = true }
    }
}

// MARK: - 翻页数字
struct FlipDigit: View {
    let value: String
    let size: CGFloat
    var accentColor: Color = Color(hex: "667eea")

    private var textGradient: LinearGradient {
        LinearGradient(
            colors: [Color.white.opacity(0.95), Color.white.opacity(0.6)],
            startPoint: .top, endPoint: .bottom
        )
    }

    var body: some View {
        Text(value)
            .font(.system(size: size, weight: .heavy, design: .rounded))
            .foregroundStyle(textGradient)
            .contentTransition(.numericText(countsDown: false))
            .frame(minWidth: size * 0.65)
            .padding(.vertical, size * 0.1)
            .padding(.horizontal, size * 0.12)
            .background(
                ZStack {
                    // 玻璃质感底层
                    RoundedRectangle(cornerRadius: size * 0.18)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.08), Color.white.opacity(0.03)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                    // 顶部高光线
                    VStack(spacing: 0) {
                        RoundedRectangle(cornerRadius: size * 0.18)
                            .fill(Color.white.opacity(0.06))
                            .frame(height: size * 0.5)
                            .mask(
                                LinearGradient(
                                    colors: [Color.white, Color.white.opacity(0)],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                        Spacer(minLength: 0)
                    }
                    // 边框
                    RoundedRectangle(cornerRadius: size * 0.18)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.15), Color.white.opacity(0.05)],
                                startPoint: .top, endPoint: .bottom
                            ),
                            lineWidth: 0.5
                        )
                }
            )
            .shadow(color: accentColor.opacity(0.15), radius: 20, y: 6)
            .shadow(color: Color.black.opacity(0.5), radius: 8, y: 4)
    }
}

// MARK: - 分体时钟（翻页式）
struct SplitClock: View {
    let time: Date
    let formatter: ClockTimeFormatter
    let primaryColor: Color
    let timerManager: TimerManager

    @State private var colonPulse = false

    private let digitSize: CGFloat = 76

    var body: some View {
        VStack(spacing: 16) {
            // 主时钟行
            HStack(spacing: 8) {
                // 小时翻页
                FlipDigit(value: formatter.hourString(time), size: digitSize, accentColor: primaryColor)

                // 冒号（呼吸脉冲）
                colonDots

                // 分钟翻页
                FlipDigit(value: formatter.minuteString(time), size: digitSize, accentColor: primaryColor)

                // 秒：仅在开启时显示
                if formatter.showSeconds {
                    colonDots
                    FlipDigit(value: formatter.seconds(time), size: digitSize * 0.5, accentColor: primaryColor)
                }
            }

            // AM/PM
            if !formatter.use24Hour {
                Text(formatter.amPM(time))
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.4))
                    .tracking(4)
            }

            if formatter.showDate {
                Text(formatter.dateString(time))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.35))
                    .tracking(2)
            }
            CountdownBadge(timerManager: timerManager)
        }
        .onAppear { colonPulse = true }
    }

    /// 冒号分隔点（带柔和脉冲动画）
    private var colonDots: some View {
        VStack(spacing: 14) {
            Circle()
                .fill(Color.white.opacity(colonPulse ? 0.5 : 0.25))
                .frame(width: 7, height: 7)
                .shadow(color: primaryColor.opacity(0.3), radius: 6)
            Circle()
                .fill(Color.white.opacity(colonPulse ? 0.5 : 0.25))
                .frame(width: 7, height: 7)
                .shadow(color: primaryColor.opacity(0.3), radius: 6)
        }
        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: colonPulse)
    }
}
