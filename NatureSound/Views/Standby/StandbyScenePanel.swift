//
//  StandbyScenePanel.swift
//  NatureSound
//
//  Created by egbert on 2026/7/11.
//

import SwiftUI

// MARK: - 场景保存面板
struct StandbyScenePanel: View {
    let audioManager: AudioManager
    let sceneManager: SceneManager
    let onInteract: () -> Void
    let onDismiss: () -> Void

    @State private var sceneName = ""
    @State private var saved = false
    @FocusState private var nameFieldFocused: Bool

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "star.fill").font(.system(size: 12)).foregroundStyle(Color(hex: "FFD54F").opacity(0.8))
                Text("保存当前场景").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.white.opacity(0.6))
                Spacer()
                Button { Haptics.light(); onDismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.3))
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Color.white.opacity(0.06)))
                }
                .buttonStyle(.plain)
            }

            if saved {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 18)).foregroundStyle(Color(hex: "5DAE7A"))
                    Text("场景已保存").font(.system(size: 13, weight: .medium)).foregroundStyle(Color.white.opacity(0.7))
                }
                .padding(.vertical, 6)
                .transition(.scale.combined(with: .opacity))
            } else {
                // 当前声音预览
                HStack(spacing: 6) {
                    ForEach(audioManager.activePlayers.prefix(5)) { player in
                        VStack(spacing: 3) {
                            Image(systemName: player.sound.icon).font(.system(size: 12)).foregroundStyle(player.sound.color.opacity(0.7))
                            Text(player.sound.name).font(.system(size: 8)).foregroundStyle(Color.white.opacity(0.3)).lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    if audioManager.activeCount > 5 {
                        Text("+\(audioManager.activeCount - 5)").font(.system(size: 11, weight: .medium)).foregroundStyle(Color.white.opacity(0.3))
                    }
                }

                // 输入
                HStack(spacing: 8) {
                    TextField("", text: $sceneName, prompt: Text("为场景起个名字…").foregroundStyle(Color.white.opacity(0.2)))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.8))
                        .focused($nameFieldFocused)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white.opacity(0.05))
                                .overlay(RoundedRectangle(cornerRadius: 10)
                                    .stroke(nameFieldFocused ? Color(hex: "667eea").opacity(0.4) : Color.white.opacity(0.08), lineWidth: 0.5))
                        )
                        .onSubmit { saveScene() }

                    Button { saveScene() } label: {
                        Image(systemName: "checkmark").font(.system(size: 13, weight: .bold))
                            .foregroundStyle(sceneName.isEmpty ? Color.white.opacity(0.2) : Color.white)
                            .frame(width: 36, height: 36)
                            .background(RoundedRectangle(cornerRadius: 10).fill(sceneName.isEmpty ? Color.white.opacity(0.05) : Color(hex: "667eea")))
                    }
                    .buttonStyle(.plain)
                    .disabled(sceneName.isEmpty)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: "FFD54F").opacity(0.12), lineWidth: 0.5))
        )
        .onAppear { nameFieldFocused = true }
    }

    private func saveScene() {
        guard !sceneName.isEmpty else { return }
        Haptics.success()
        let ids = audioManager.activePlayers.map { $0.sound.id }
        var vols: [String: Float] = [:]
        for p in audioManager.activePlayers { vols[p.sound.id] = p.volume }
        sceneManager.saveCurrentScene(name: sceneName, soundIDs: ids, volumes: vols)
        withAnimation(.spring(response: 0.35)) { saved = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { onDismiss() }
    }
}
