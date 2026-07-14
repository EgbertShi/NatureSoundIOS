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

    private var timer: Foundation.Timer?
    private var onCompleteCallback: (() -> Void)?

    /// 淡出开始的秒数
    static let fadeOutSeconds = 30

    static let presetMinutes = [5, 10, 15, 20, 30, 45, 60, 90, 120]

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

    func start(onComplete: @escaping () -> Void) {
        remainingSeconds = selectedMinutes * 60
        isActive = true
        isFadingOut = false
        onCompleteCallback = onComplete
        timer?.invalidate()
        timer = Foundation.Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            if self.remainingSeconds > 0 {
                self.remainingSeconds -= 1
                if self.remainingSeconds <= Self.fadeOutSeconds && !self.isFadingOut {
                    self.isFadingOut = true
                }
            } else {
                self.stop()
                self.onCompleteCallback?()
                self.onCompleteCallback = nil
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        isActive = false
        isFadingOut = false
        remainingSeconds = 0
        onCompleteCallback = nil
    }

    func addMinutes(_ minutes: Int) {
        guard isActive else { return }
        remainingSeconds += minutes * 60
        if remainingSeconds > Self.fadeOutSeconds && isFadingOut { isFadingOut = false }
    }
}
