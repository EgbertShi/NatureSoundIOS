//
//  TimerManager.swift
//  NatureSound
//
//  Created by egbert on 2026/7/1.
//

import Foundation

@Observable
final class TimerManager {
    var isActive = false
    var remainingSeconds: Int = 0
    var selectedMinutes: Int = 30
    var isFadingOut = false

    /// 当前活跃的模式（入睡/专注/放松/冥想），nil 表示无模式的普通定时
    var currentMode: FocusMode?

    /// 唤醒触发标记：定时结束且当前模式需要唤醒时置为 true，
    /// 由 ContentView 监听后展示唤醒 Overlay。
    var wakeUpTriggered = false

    /// 本次定时的总时长（分钟），用于唤醒窗口展示"你已专注了 X 分钟"
    var totalMinutes: Int = 0

    private var timer: Foundation.Timer?
    private var onCompleteCallback: (() -> Void)?

    /// 淡出开始的秒数
    static let fadeOutSeconds = 30

    static let presetMinutes = [5, 10, 15, 20, 30, 45, 60, 90, 120]

    // MARK: - 唤醒铃声设置
    private static let wakeUpToneKey = "NatureSound_WakeUpToneID"

    /// 当前选中的唤醒铃声 ID
    var selectedWakeUpToneID: String {
        get { UserDefaults.standard.string(forKey: Self.wakeUpToneKey) ?? WakeUpTone.defaultTone.id }
        set { UserDefaults.standard.set(newValue, forKey: Self.wakeUpToneKey) }
    }

    /// 当前选中的唤醒铃声
    var selectedWakeUpTone: WakeUpTone {
        WakeUpTone.tone(for: selectedWakeUpToneID)
    }

    var displayTime: String {
        String(format: "%02d:%02d", remainingSeconds / 60, remainingSeconds % 60)
    }

    var progress: Double {
        guard selectedMinutes > 0 else { return 0 }
        return 1.0 - Double(remainingSeconds) / Double(selectedMinutes * 60)
    }

    /// 当前淡出比例（0=正常音量, 1=完全静音）
    var fadeOutProgress: Float {
        guard isFadingOut, remainingSeconds > 0 else { return 0 }
        return 1.0 - Float(remainingSeconds) / Float(Self.fadeOutSeconds)
    }

    // MARK: - 定时控制

    /// 启动定时器（普通模式，无 FocusMode）
    func start(onComplete: @escaping () -> Void) {
        startTimer(mode: nil, minutes: selectedMinutes, onComplete: onComplete)
    }

    /// 启动定时器（带模式）
    func start(mode: FocusMode, minutes: Int, onComplete: @escaping () -> Void) {
        selectedMinutes = minutes
        startTimer(mode: mode, minutes: minutes, onComplete: onComplete)
    }

    private func startTimer(mode: FocusMode?, minutes: Int, onComplete: @escaping () -> Void) {
        currentMode = mode
        totalMinutes = minutes
        remainingSeconds = minutes * 60
        isActive = true
        isFadingOut = false
        wakeUpTriggered = false
        onCompleteCallback = onComplete
        timer?.invalidate()
        timer = Foundation.Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            if self.remainingSeconds > 0 {
                self.remainingSeconds -= 1
                // 需要唤醒的模式不做淡出（保持音量，等待用户交互）
                let shouldFadeOut = !(self.currentMode?.needsWakeUp ?? false)
                if shouldFadeOut && self.remainingSeconds <= Self.fadeOutSeconds && !self.isFadingOut {
                    self.isFadingOut = true
                }
            } else {
                self.handleTimerEnd()
            }
        }
    }

    /// 定时结束的统一处理
    private func handleTimerEnd() {
        timer?.invalidate()
        timer = nil

        if let mode = currentMode, mode.needsWakeUp {
            // 需要唤醒的模式：不停止播放，标记唤醒
            isActive = false
            isFadingOut = false
            wakeUpTriggered = true
            // 不清除 currentMode 和 totalMinutes，唤醒窗口需要用
        } else {
            // 入睡模式或无模式：执行回调（停止播放）
            isActive = false
            isFadingOut = false
            remainingSeconds = 0
            onCompleteCallback?()
            onCompleteCallback = nil
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        isActive = false
        isFadingOut = false
        remainingSeconds = 0
        wakeUpTriggered = false
        currentMode = nil
        totalMinutes = 0
        onCompleteCallback = nil
    }

    /// 唤醒窗口中用户选择"继续"后调用
    func dismissWakeUp() {
        wakeUpTriggered = false
        currentMode = nil
        totalMinutes = 0
    }

    /// 唤醒窗口中用户选择"停止"后调用
    func stopFromWakeUp() {
        wakeUpTriggered = false
        currentMode = nil
        totalMinutes = 0
        onCompleteCallback?()
        onCompleteCallback = nil
    }

    func addMinutes(_ minutes: Int) {
        guard isActive else { return }
        remainingSeconds += minutes * 60
        if remainingSeconds > Self.fadeOutSeconds && isFadingOut { isFadingOut = false }
    }
}
