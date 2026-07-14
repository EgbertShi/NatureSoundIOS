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
    @State private var sceneToDelete: UserScene?
    @State private var sceneToRename: UserScene?
    @State private var renameText = ""

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                if sceneManager.userScenes.isEmpty {
                    emptyState
                } else {
                    Text("我的场景")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.8))
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

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
                .foregroundStyle(Color.white.opacity(0.15))
            Text("还没有保存的场景")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.4))
            Text("在播放器中点击「保存为场景」\n即可在这里找到你的专属组合")
                .font(.system(size: 13))
                .foregroundStyle(Color.white.opacity(0.3))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 400)
    }

    private func applyUserScene(_ scene: UserScene) {
        Haptics.medium()
        audioManager.stopAll()
        for soundID in scene.soundIDs {
            if let sound = SoundItem.allSounds.first(where: { $0.id == soundID }) {
                audioManager.addSound(sound, volume: scene.volumes[soundID] ?? 0.7)
            }
        }
    }
}
