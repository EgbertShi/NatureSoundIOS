//
//  LiveActivityManager.swift
//  NatureSound
//
//  Created by egbert on 2026/7/24.
//

#if os(iOS) && !targetEnvironment(macCatalyst)
import ActivityKit
import Foundation
import os

// MARK: - Live Activity 定时器属性

struct NatureSoundTimerAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var remainingSeconds: Int
        var totalSeconds: Int
        var soundNames: [String]
    }

    var totalMinutes: Int
    var startedAt: Date
}

// MARK: - Live Activity 管理器

@Observable
final class LiveActivityManager {
    private var currentActivity: Activity<NatureSoundTimerAttributes>?
    private var updateTimer: Foundation.Timer?

    var isSupported: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    /// 启动 Live Activity
    func startActivity(totalMinutes: Int, remainingSeconds: Int, soundNames: [String]) {
        guard isSupported else { return }
        endActivity()

        let attributes = NatureSoundTimerAttributes(
            totalMinutes: totalMinutes,
            startedAt: .now
        )
        let state = NatureSoundTimerAttributes.ContentState(
            remainingSeconds: remainingSeconds,
            totalSeconds: totalMinutes * 60,
            soundNames: soundNames
        )
        do {
            let content = ActivityContent(
                state: state,
                staleDate: nil
            )
            currentActivity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
        } catch {
            AppLogger.liveActivity.error("启动 Live Activity 失败: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// 更新 Live Activity 状态
    func updateActivity(remainingSeconds: Int, totalSeconds: Int, soundNames: [String]) {
        guard let activity = currentActivity else { return }
        let state = NatureSoundTimerAttributes.ContentState(
            remainingSeconds: remainingSeconds,
            totalSeconds: totalSeconds,
            soundNames: soundNames
        )
        Task {
            await activity.update(
                ActivityContent(state: state, staleDate: nil)
            )
        }
    }

    /// 结束 Live Activity
    func endActivity() {
        guard let activity = currentActivity else { return }
        Task {
            await activity.end(
                ActivityContent(
                    state: activity.content.state,
                    staleDate: nil
                ),
                dismissalPolicy: .immediate
            )
        }
        currentActivity = nil
    }
}

#else

import Foundation

// MARK: - Live Activity 管理器 (Mac Catalyst 占位)

@Observable
final class LiveActivityManager {
    var isSupported: Bool { false }

    func startActivity(totalMinutes: Int, remainingSeconds: Int, soundNames: [String]) {}
    func updateActivity(remainingSeconds: Int, totalSeconds: Int, soundNames: [String]) {}
    func endActivity() {}
}

#endif
