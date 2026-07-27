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

    var body: some View {
        ZStack {
            // 所有已缓存版本同时存在，滑动仅切换 opacity。
            // videoLayer 内部读取了 videoManager 的缓存状态，
            // 由于 VideoManager 现已标记为 @Observable，下载完成后会自动驱动本视图重新求值，
            // 无需再依赖本地额外的版本计数器。
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
        // 当前版本视频尚未本地缓存时，先下载缩略图再下载视频。
        // VideoManager 内部在写盘成功后会递增其 @Observable 的 cacheVersion，
        // 自动驱动本视图重新求值，无需再手动维护本地状态。
        if videoManager.cachedVideoURL(for: scene.id, variantIndex: variantIndex) == nil {
            await videoManager.cacheThumbnail(for: scene.id, variantIndex: variantIndex)
            guard !Task.isCancelled else { return }
            await videoManager.cacheAsset(for: scene.id, variantIndex: variantIndex)
            guard !Task.isCancelled else { return }
        }

        // 预缓存其余视频
        for idx in 0..<variantCount where idx != variantIndex {
            guard !Task.isCancelled else { break }
            let existedBefore = videoManager.cachedVideoURL(for: scene.id, variantIndex: idx) != nil
            if !existedBefore {
                await videoManager.cacheAsset(for: scene.id, variantIndex: idx)
                guard !Task.isCancelled else { break }
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
