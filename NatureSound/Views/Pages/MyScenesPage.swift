//
//  MyScenesPage.swift
//  NatureSound
//
//  Created by egbert on 2026/7/1.
//

import SwiftUI

// MARK: - 我的场景页面
struct MyScenesPage: View {
    let audioManager: AudioManager
    let sceneManager: SceneManager
    @Binding var showSettings: Bool
    @State private var sceneToDelete: UserScene?
    @State private var sceneToRename: UserScene?
    @State private var renameText = ""

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                // 页面标题栏
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("我的")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.textPrimary(.light))
                        Text("保存你的专属声音组合")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.textTertiary(.light))
                    }
                    Spacer()
                    Button {
                        Haptics.light()
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Theme.iconDefault(.light))
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Theme.inactiveFill(.light)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 54)

                if sceneManager.userScenes.isEmpty {
                    emptyState
                } else {
                    Text("我的场景")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary(.light))
                        .padding(.horizontal, 20)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                        ForEach(sceneManager.userScenes) { scene in
                            UserSceneCard(
                                scene: scene,
                                onTap: { applyUserScene(scene) },
                                onDelete: { sceneToDelete = scene },
                                onRename: { sceneToRename = scene; renameText = scene.name }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.bottom, audioManager.activeCount > 0 ? 160 : 40)
        }
        .alert("删除场景", isPresented: Binding(get: { sceneToDelete != nil }, set: { if !$0 { sceneToDelete = nil } })) {
            Button("删除", role: .destructive) {
                if let scene = sceneToDelete {
                    Haptics.success()
                    withAnimation { sceneManager.deleteScene(scene) }
                    sceneToDelete = nil
                }
            }
            Button("取消", role: .cancel) { sceneToDelete = nil }
        } message: {
            if let scene = sceneToDelete { Text("确定要删除「\(scene.name)」吗？此操作无法撤销。") }
        }
        .alert("重命名场景", isPresented: Binding(get: { sceneToRename != nil }, set: { if !$0 { sceneToRename = nil } })) {
            TextField("场景名称", text: $renameText)
            Button("确定") {
                if let scene = sceneToRename, !renameText.isEmpty {
                    Haptics.success()
                    sceneManager.renameScene(scene, to: renameText)
                }
                sceneToRename = nil
            }
            Button("取消", role: .cancel) { sceneToRename = nil }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "star")
                .font(.system(size: 44))
                .foregroundStyle(Theme.textTertiary(.light).opacity(0.5))
            Text("还没有保存的场景")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.textSecondary(.light))
            Text("在播放器中点击「保存为场景」\n即可在这里找到你的专属组合")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textTertiary(.light))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 400)
    }

    private func applyUserScene(_ scene: UserScene) {
        Haptics.medium()
        withAnimation(.spring(response: 0.4)) {
            audioManager.stopAll()
            for soundID in scene.soundIDs {
                if let sound = SoundItem.allSounds.first(where: { $0.id == soundID }) {
                    audioManager.addSound(sound, volume: scene.volumes[soundID] ?? 0.7)
                }
            }
        }
    }
}
