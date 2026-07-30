//
//  ModeSetupSheet.swift
//  NatureSound
//
//  Created by egbert on 2026/7/30.
//

import SwiftUI

// MARK: - 模式设置面板
/// 半屏 Sheet（.medium），紧凑布局：大字时间 + 横向刻度尺 + 场景 tab 切换 + 开始按钮。
struct ModeSetupSheet: View {
    let mode: FocusMode
    let audioManager: AudioManager
    let timerManager: TimerManager
    let videoManager: VideoManager
    @Binding var isPresented: Bool
    let onStart: (ScenePreset, Int) -> Void

    @State private var selectedMinutes: Int
    @State private var selectedScene: ScenePreset?
    /// 场景 tab：0=推荐，1=更多
    @State private var sceneTab = 0
    @Environment(\.colorScheme) private var colorScheme

    private var recommendedScenes: [ScenePreset] {
        ScenePreset.allPresets.filter { $0.tags.contains(mode.matchingTag) }
    }

    private var otherScenes: [ScenePreset] {
        let recommendedIDs = Set(recommendedScenes.map { $0.id })
        return ScenePreset.allPresets.filter { !recommendedIDs.contains($0.id) }
    }

    init(mode: FocusMode, audioManager: AudioManager, timerManager: TimerManager, videoManager: VideoManager, isPresented: Binding<Bool>, onStart: @escaping (ScenePreset, Int) -> Void) {
        self.mode = mode
        self.audioManager = audioManager
        self.timerManager = timerManager
        self.videoManager = videoManager
        self._isPresented = isPresented
        self.onStart = onStart
        self._selectedMinutes = State(initialValue: mode.defaultMinutes)
        let recommended = ScenePreset.allPresets.filter { $0.tags.contains(mode.matchingTag) }
        self._selectedScene = State(initialValue: recommended.first)
    }

    // MARK: - 颜色适配

    private var bgPrimary: Color {
        colorScheme == .dark ? Color(hex: "0E1117") : Color(hex: "F8F9FB")
    }
    private var bgCard: Color {
        colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04)
    }
    private var textPrimary: Color {
        colorScheme == .dark ? .white : Color(hex: "1A1A1A")
    }
    private var textSecondary: Color {
        colorScheme == .dark ? .white.opacity(0.55) : Color(hex: "8E8E93")
    }
    private var textTertiary: Color {
        colorScheme == .dark ? .white.opacity(0.3) : Color(hex: "C7C7CC")
    }
    private var dividerColor: Color {
        colorScheme == .dark ? .white.opacity(0.06) : .black.opacity(0.06)
    }

    var body: some View {
        VStack(spacing: 0) {
            // MARK: 顶部导航
            sheetHeader
                .padding(.top, 12)

            // MARK: 时间 + 刻度尺
            timeDisplay
                .padding(.top, 10)

            TickRulerView(
                selectedMinutes: $selectedMinutes,
                range: FocusMode.timerRange,
                accentColor: mode.themeColor,
                textColor: textSecondary,
                tickColor: textTertiary
            )
            .frame(height: 48)
            .padding(.top, 2)

            endTimeLabel
                .padding(.top, 4)

            // MARK: 快捷时长
            quickDurationRow
                .padding(.top, 10)

            // MARK: 分隔线
            dividerColor.frame(height: 0.5)
                .padding(.horizontal, 20)
                .padding(.top, 12)

            // MARK: 场景 tab + 列表
            sceneTabBar
                .padding(.top, 10)

            sceneList
                .padding(.top, 8)

            Spacer(minLength: 0)

            // MARK: 开始按钮
            startButton
        }
        .background(bgPrimary.ignoresSafeArea())
    }

    // MARK: - 顶部导航栏

    private var sheetHeader: some View {
        HStack {
            Button {
                isPresented = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(textSecondary)
            }

            Spacer()

            HStack(spacing: 5) {
                Image(systemName: mode.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(mode.themeColor)
                Text(mode.displayName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(textPrimary)
            }

            Spacer()

            // 唤醒铃声按钮（非入睡模式可选铃声）
            if mode.needsWakeUp {
                Menu {
                    ForEach(WakeUpTone.allTones) { tone in
                        Button {
                            Haptics.light()
                            timerManager.selectedWakeUpToneID = tone.id
                        } label: {
                            HStack {
                                Text(tone.name)
                                if timerManager.selectedWakeUpToneID == tone.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(mode.themeColor)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(mode.themeColor.opacity(0.12)))
                }
            } else {
                // 占位，保持标题居中
                Color.clear.frame(width: 32, height: 32)
            }
        }
        .padding(.horizontal, 18)
    }

    // MARK: - 大字时间

    private var timeDisplay: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("\(selectedMinutes)")
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .foregroundStyle(textPrimary)
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.2), value: selectedMinutes)
            Text("分钟")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(textSecondary)
        }
    }

    // MARK: - 结束时间

    private var endTimeLabel: some View {
        let endTime = Calendar.current.date(byAdding: .minute, value: selectedMinutes, to: Date()) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let timeStr = formatter.string(from: endTime)

        return Text(mode == .sleep ? "将于 \(timeStr) 停止播放" : "闹钟将于 \(timeStr) 响起")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(textSecondary)
    }

    // MARK: - 快捷时长

    private var quickDurationRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(mode.quickDurations, id: \.self) { minutes in
                    let isSelected = selectedMinutes == minutes
                    Button {
                        Haptics.light()
                        withAnimation(.snappy(duration: 0.2)) {
                            selectedMinutes = minutes
                        }
                    } label: {
                        Text(Self.formatDuration(minutes))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(isSelected ? .white : textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                Capsule()
                                    .fill(isSelected ? mode.themeColor : bgCard)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - 场景 Tab 栏

    private var sceneTabBar: some View {
        HStack(spacing: 0) {
            tabButton(title: "推荐", index: 0)
            tabButton(title: "更多场景", index: 1)
            Spacer()
        }
        .padding(.horizontal, 20)
    }

    private func tabButton(title: String, index: Int) -> some View {
        Button {
            Haptics.light()
            withAnimation(.snappy(duration: 0.2)) {
                sceneTab = index
            }
        } label: {
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: sceneTab == index ? .bold : .medium))
                    .foregroundStyle(sceneTab == index ? textPrimary : textSecondary)

                RoundedRectangle(cornerRadius: 1)
                    .fill(sceneTab == index ? mode.themeColor : .clear)
                    .frame(width: 20, height: 2)
            }
        }
        .buttonStyle(.plain)
        .padding(.trailing, 18)
    }

    // MARK: - 场景列表（横向滑动）

    private var sceneList: some View {
        let scenes = sceneTab == 0 ? recommendedScenes : otherScenes

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(scenes) { scene in
                    modeSceneCard(scene)
                }
            }
            .padding(.horizontal, 20)
        }
        .id(sceneTab) // tab 切换时重置滚动位置
    }

    private func modeSceneCard(_ scene: ScenePreset) -> some View {
        let isSelected = selectedScene?.id == scene.id

        return Button {
            Haptics.light()
            withAnimation(.spring(response: 0.3)) {
                selectedScene = scene
            }
        } label: {
            HStack(spacing: 10) {
                // 缩略图 / 兜底色块
                ZStack {
                    if let thumb = videoManager.cachedThumbnailImage(for: scene.id, variantIndex: 0) {
                        Image(uiImage: thumb)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 52, height: 52)
                            .clipped()
                    } else {
                        LinearGradient(
                            colors: [scene.color.opacity(0.5), scene.color.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .overlay(
                            Image(systemName: scene.icon)
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(.white.opacity(0.6))
                        )
                        .frame(width: 52, height: 52)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                // 名称 + 声音数
                VStack(alignment: .leading, spacing: 2) {
                    Text(scene.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(textPrimary)
                        .lineLimit(1)

                    Text("\(scene.soundIDs.count) 种声音")
                        .font(.system(size: 10))
                        .foregroundStyle(textSecondary)
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.04) : .white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? mode.themeColor.opacity(0.6) : dividerColor, lineWidth: isSelected ? 1.5 : 0.5)
            )
        }
        .buttonStyle(.plain)
        .task(id: scene.id) {
            await videoManager.cacheThumbnail(for: scene.id)
        }
    }

    // MARK: - 开始按钮

    private var startButton: some View {
        Button {
            guard let scene = selectedScene else { return }
            Haptics.medium()
            isPresented = false
            onStart(scene, selectedMinutes)
        } label: {
            Text("开始\(mode.displayName)")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(mode.themeColor)
                )
        }
        .buttonStyle(.plain)
        .disabled(selectedScene == nil)
        .opacity(selectedScene == nil ? 0.45 : 1)
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }

    // MARK: - 辅助

    private static func formatDuration(_ minutes: Int) -> String {
        if minutes >= 60 {
            return minutes % 60 == 0 ? "\(minutes / 60)小时" : "\(minutes / 60)小时\(minutes % 60)分"
        }
        return "\(minutes)分钟"
    }
}

// MARK: - 横向刻度尺选择器
struct TickRulerView: View {
    @Binding var selectedMinutes: Int
    let range: ClosedRange<Int>
    let accentColor: Color
    let textColor: Color
    let tickColor: Color

    private let pointsPerMinute: CGFloat = 6
    private let step = 5

    @State private var dragOffset: CGFloat = 0
    @State private var lastDragOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let center = geo.size.width / 2

            ZStack {
                Canvas { context, size in
                    let totalTicks = (range.upperBound - range.lowerBound) / step + 1
                    let currentOffset = -CGFloat(selectedMinutes - range.lowerBound) * pointsPerMinute + dragOffset

                    for i in 0..<totalTicks {
                        let minute = range.lowerBound + i * step
                        let x = center + CGFloat(i) * pointsPerMinute * CGFloat(step) + currentOffset

                        guard x > -20 && x < size.width + 20 else { continue }

                        let isMajor = minute % 10 == 0
                        let tickHeight: CGFloat = isMajor ? 16 : 8
                        let tickWidth: CGFloat = isMajor ? 2.5 : 1.5

                        let distFromCenter = abs(x - center)
                        let maxDist = size.width / 2
                        let alpha = max(0.15, 1.0 - (distFromCenter / maxDist) * 0.7)

                        let tickRect = CGRect(
                            x: x - tickWidth / 2,
                            y: (size.height - tickHeight) / 2,
                            width: tickWidth,
                            height: tickHeight
                        )
                        context.fill(
                            Path(roundedRect: tickRect, cornerRadius: tickWidth / 2),
                            with: .color(tickColor.opacity(alpha))
                        )
                    }
                }

                // 中心指示线
                RoundedRectangle(cornerRadius: 2)
                    .fill(accentColor)
                    .frame(width: 3, height: 28)
                    .shadow(color: accentColor.opacity(0.4), radius: 4, y: 0)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        dragOffset = value.translation.width + lastDragOffset
                        let minutesDelta = -Int((dragOffset / pointsPerMinute).rounded())
                        let rawMinutes = clampedMinutes(delta: minutesDelta)
                        let snapped = max(range.lowerBound, min(range.upperBound, Int((Double(rawMinutes) / Double(step)).rounded()) * step))
                        if snapped != selectedMinutes {
                            selectedMinutes = snapped
                            Haptics.selection()
                        }
                    }
                    .onEnded { _ in
                        withAnimation(.snappy(duration: 0.25)) {
                            dragOffset = 0
                            lastDragOffset = 0
                        }
                    }
            )
        }
    }

    private func clampedMinutes(delta: Int) -> Int {
        let base = selectedMinutes
        return max(range.lowerBound, min(range.upperBound, base + delta))
    }
}
