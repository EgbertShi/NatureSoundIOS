//
//  ImmersiveVideoBackground.swift
//  NatureSound
//
//  Created by egbert on 2026/7/25.
//

import SwiftUI

// MARK: - 沉浸场景视频背景
// 仅使用本地缓存媒体；首次进入时下载当前场景的所有版本，完成后原地展示
struct ImmersiveVideoBackground: View {
    let scene: ScenePreset
    let variantIndex: Int
    let variantCount: Int
    let videoManager: VideoManager
    @State private var cacheVersion = 0

    var body: some View {
        ZStack {
            // cacheVersion 作为隐形视图参与 body 求值，下载完成后触发刷新，
            // 但不销毁已有图层（避免 .id 导致播放器重建闪烁）。
            Color.clear
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
                .id(cacheVersion)

            // 所有已缓存版本同时存在，滑动仅切换 opacity
            ForEach(0..<variantCount, id: \.self) { idx in
                videoLayer(variantIndex: idx)
                    .opacity(idx == variantIndex ? 1 : 0)
            }

            LinearGradient(
                colors: [Color.black.opacity(0.25), .clear, Color.black.opacity(0.35)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.4), value: variantIndex)
        .task(id: scene.id) {
            await cacheAllVariants()
        }
    }

    // MARK: - 单个视频层（仅本地缓存）

    @ViewBuilder
    private func videoLayer(variantIndex idx: Int) -> some View {
        ZStack {
            // 预览图只用于当前正在加载的视频，不为指示器中的其他索引加载图片。
            if idx == variantIndex, let image = videoManager.cachedThumbnailImage(for: scene.id, variantIndex: idx) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                LinearGradient(
                    colors: [scene.color.opacity(0.7), .black],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            if let videoURL = videoManager.cachedVideoURL(for: scene.id, variantIndex: idx) {
                LoopingVideoPlayer(url: videoURL, isActive: idx == variantIndex)
                    .id("video-\(idx)")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private func cacheAllVariants() async {
        // 当前版本视频已在本地时无需触发刷新——首次 body 求值已包含所有已缓存视频。
        // 仅在需要下载时才递增 cacheVersion，避免不必要的 body 重算导致播放器重建。
        if videoManager.cachedVideoURL(for: scene.id, variantIndex: variantIndex) == nil {
            // 首次加载：先展示本地缓存的预览图，随后下载视频。
            await videoManager.cacheThumbnail(for: scene.id, variantIndex: variantIndex)
            guard !Task.isCancelled else { return }
            await MainActor.run { cacheVersion += 1 }

            await videoManager.cacheAsset(for: scene.id, variantIndex: variantIndex)
            guard !Task.isCancelled else { return }
            await MainActor.run { cacheVersion += 1 }
        }

        // 预缓存其余视频；仅在新增缓存时触发刷新
        for idx in 0..<variantCount where idx != variantIndex {
            guard !Task.isCancelled else { break }
            let existedBefore = videoManager.cachedVideoURL(for: scene.id, variantIndex: idx) != nil
            if !existedBefore {
                await videoManager.cacheAsset(for: scene.id, variantIndex: idx)
                guard !Task.isCancelled else { break }
                await MainActor.run { cacheVersion += 1 }
            }
        }
    }
}

// MARK: - 页面指示器
struct VideoPageIndicator: View {
    let count: Int
    let current: Int

    var body: some View {
        if count > 1 {
            HStack(spacing: 6) {
                ForEach(0..<count, id: \.self) { idx in
                    Capsule()
                        .fill(Color.white.opacity(idx == current ? 0.9 : 0.3))
                        .frame(width: idx == current ? 16 : 6, height: 6)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: current)
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .background(Capsule().fill(.ultraThinMaterial).opacity(0.5))
        }
    }
}
