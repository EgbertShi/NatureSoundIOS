//
//  SettingsPage.swift
//  NatureSound
//
//  Created by egbert on 2026/7/1.
//

import SwiftUI

// MARK: - 设置页面
struct SettingsPage: View {
    let audioManager: AudioManager
    let sceneManager: SceneManager
    @Binding var isPresented: Bool
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    @State private var showClearScenesAlert = false
    @State private var showResetWelcomeAlert = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    appInfoSection
                    dataManagementSection
                    otherSettingsSection
                    aboutSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .background(Theme.settingsBg(colorScheme).ignoresSafeArea())
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { isPresented = false }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.accent)
                }
            }
            .alert("清除全部场景", isPresented: $showClearScenesAlert) {
                Button("清除", role: .destructive) { Haptics.success(); sceneManager.clearAllScenes() }
                Button("取消", role: .cancel) {}
            } message: {
                Text("确定要删除全部 \(sceneManager.userScenes.count) 个自定义场景吗？此操作无法撤销。")
            }
            .alert("重置引导页", isPresented: $showResetWelcomeAlert) {
                Button("重置", role: .destructive) { Haptics.success(); hasSeenWelcome = false }
                Button("取消", role: .cancel) {}
            } message: {
                Text("下次启动应用时将重新显示欢迎引导。")
            }
        }
    }

    // MARK: - 应用信息
    private var appInfoSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 36))
                .foregroundStyle(Theme.accentGradient)
            Text("清籁")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary(colorScheme))
            Text("聆听自然 · 疗愈心灵")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary(colorScheme))
        }
        .padding(.top, 8)
    }

    // MARK: - 数据管理
    private var dataManagementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("数据管理")
            Button {
                Haptics.light()
                showClearScenesAlert = true
            } label: {
                settingRow(icon: "trash.circle.fill", iconColor: Theme.danger, title: "清除全部自定义场景", subtitle: "当前 \(sceneManager.userScenes.count) 个场景")
            }
            .buttonStyle(.plain)
            .disabled(sceneManager.userScenes.isEmpty)
        }
    }

    // MARK: - 其他设置
    private var otherSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("其他")
            Button {
                Haptics.light()
                showResetWelcomeAlert = true
            } label: {
                settingRow(icon: "questionmark.circle.fill", iconColor: Theme.accent, title: "重置引导页", subtitle: "下次启动时显示欢迎引导")
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 关于
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("关于")
            VStack(spacing: 0) {
                settingRow(icon: "info.circle.fill", iconColor: Theme.iconDefault(colorScheme), title: "版本", trailing: "1.1")
                Divider().background(Theme.separator(colorScheme)).padding(.horizontal, 14)
                settingRow(icon: "waveform.circle.fill", iconColor: Theme.iconDefault(colorScheme), title: "声音库", trailing: "\(SoundItem.allSounds.count) 种声音")
                Divider().background(Theme.separator(colorScheme)).padding(.horizontal, 14)
                settingRow(icon: "square.stack.3d.up.fill", iconColor: Theme.iconDefault(colorScheme), title: "预设场景", trailing: "\(ScenePreset.allPresets.count) 个场景")
            }
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.inactiveFill(colorScheme)))
        }
    }

    // MARK: - 复用组件
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Theme.textSecondary(colorScheme))
    }

    private func settingRow(icon: String, iconColor: Color, title: String, subtitle: String? = nil, trailing: String? = nil) -> some View {
        HStack {
            Image(systemName: icon).font(.system(size: 18)).foregroundStyle(iconColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.textPrimary(colorScheme))
                if let subtitle { Text(subtitle).font(.system(size: 11)).foregroundStyle(Theme.textSecondary(colorScheme)) }
            }
            Spacer()
            if let trailing {
                Text(trailing).font(.system(size: 13, design: .monospaced)).foregroundStyle(Theme.textSecondary(colorScheme))
            } else {
                Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(Theme.textTertiary(colorScheme))
            }
        }
        .padding(14)
        .background(
            Group {
                if subtitle != nil {
                    RoundedRectangle(cornerRadius: 12).fill(Theme.inactiveFill(colorScheme))
                } else {
                    Color.clear
                }
            }
        )
    }
}
