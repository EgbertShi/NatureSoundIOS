//
//  Haptics.swift
//  NatureSound
//
//  Created by egbert on 2026/7/1.
//

import UIKit

// MARK: - 触觉反馈工具
enum Haptics {
    static func light()     { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func medium()    { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func soft()      { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    static func success()   { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func selection() { UISelectionFeedbackGenerator().selectionChanged() }
}
