//
//  VideoManager.swift
//  NatureSound
//
//  Created by egbert on 2026/7/15.
//

import SwiftUI
import AVFoundation

// MARK: - videos.json 数据模型

private struct VideoIndex: Decodable {
    let baseURL: String
    let videos: [VideoEntry]
}

private struct VideoEntry: Decodable {
    let sceneID: String
    let name: String
    let videos: [VideoAsset]
}

private struct VideoAsset: Decodable {
    let videoPath: String
    let thumbnailPath: String
    let fileSize: Int
}

// MARK: - 场景视频管理器
// 负责解析场景视频/缩略图索引（videos.json），并提供 OSS 远程 URL
// 缓存文件名直接取自服务端路径中的文件名，保证本地与远程一一对应

final class VideoManager {
    /// 每个 sceneID 对应的资源条目
    private var entries: [String: VideoEntry] = [:]
    /// OSS 基础 URL
    private var baseURL: String = ""

    /// 内存缓存：缩略图
    private var thumbnailCache: [String: UIImage] = [:]
    /// 正在下载中的资源缓存任务（用远程文件名作为 key，避免重复下载）
    private var caching: Set<String> = []

    private let fm = FileManager.default

    init() {
        loadVideoIndex()
    }

    // MARK: - 索引加载（从 bundle 内的 videos.json）

    private func loadVideoIndex() {
        guard let url = Bundle.main.url(forResource: "videos", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("[VideoManager] 未找到 videos.json")
            return
        }
        do {
            let index = try JSONDecoder().decode(VideoIndex.self, from: data)
            baseURL = index.baseURL
            for entry in index.videos {
                entries[entry.sceneID] = entry
            }
        } catch {
            print("[VideoManager] 解析 videos.json 失败: \(error.localizedDescription)")
        }
    }

    // MARK: - 公开接口：远程 URL

    /// 场景缩略图的远程 URL（用于 AsyncImage 展示精选场景卡片背景）
    func thumbnailURL(for sceneID: String, variantIndex: Int = 0) -> URL? {
        guard let asset = videoAsset(for: sceneID, variantIndex: variantIndex) else { return nil }
        let raw = baseURL + "/" + asset.thumbnailPath
        return URL(string: raw) ?? URL(string: raw.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? raw)
    }

    /// 场景视频的远程 URL
    func videoURL(for sceneID: String, variantIndex: Int = 0) -> URL? {
        guard let asset = videoAsset(for: sceneID, variantIndex: variantIndex) else { return nil }
        let raw = baseURL + "/" + asset.videoPath
        return URL(string: raw) ?? URL(string: raw.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? raw)
    }

    /// 指定场景可用的视频版本数量
    func videoVariantCount(for sceneID: String) -> Int {
        entries[sceneID]?.videos.count ?? 0
    }

    private func videoAsset(for sceneID: String, variantIndex: Int) -> VideoAsset? {
        guard let videos = entries[sceneID]?.videos, !videos.isEmpty else { return nil }
        let index = min(max(variantIndex, 0), videos.count - 1)
        return videos[index]
    }

    /// 是否存在该场景的视频/缩略图资源索引
    func hasAsset(for sceneID: String) -> Bool {
        entries[sceneID] != nil
    }

    // MARK: - 从服务端路径提取本地缓存文件名

    /// 从服务端 videoPath 提取文件名作为本地缓存名（如 "场景视频/forest_meditation_1.mp4" → "forest_meditation_1.mp4"）
    private func videoCacheFileName(for sceneID: String, variantIndex: Int) -> String? {
        guard let asset = videoAsset(for: sceneID, variantIndex: variantIndex) else { return nil }
        return URL(string: asset.videoPath)?.lastPathComponent
            ?? (asset.videoPath as NSString).lastPathComponent
    }

    /// 从服务端 thumbnailPath 提取文件名作为本地缓存名
    private func thumbnailCacheFileName(for sceneID: String, variantIndex: Int) -> String? {
        guard let asset = videoAsset(for: sceneID, variantIndex: variantIndex) else { return nil }
        return URL(string: asset.thumbnailPath)?.lastPathComponent
            ?? (asset.thumbnailPath as NSString).lastPathComponent
    }

    // MARK: - 本地媒体缓存

    /// 仅返回已落盘的缩略图；未命中时由调用方展示本地占位图。
    func cachedThumbnailImage(for sceneID: String, variantIndex: Int) -> UIImage? {
        guard let fileName = thumbnailCacheFileName(for: sceneID, variantIndex: variantIndex) else { return nil }
        if let image = thumbnailCache[fileName] { return image }
        let url = thumbnailCacheDirectory.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: url), let image = UIImage(data: data) else { return nil }
        thumbnailCache[fileName] = image
        return image
    }

    /// 仅返回已落盘的视频 URL，播放器绝不直接访问远程 OSS 地址。
    func cachedVideoURL(for sceneID: String, variantIndex: Int) -> URL? {
        guard let fileName = videoCacheFileName(for: sceneID, variantIndex: variantIndex) else { return nil }
        let url = videoCacheDirectory.appendingPathComponent(fileName)
        let exists = fm.fileExists(atPath: url.path)
        print("📀 [VideoManager] cachedVideoURL(\(sceneID), \(variantIndex)): fileName=\(fileName), exists=\(exists)")
        return exists ? url : nil
    }

    /// 缓存指定版本的缩略图，供卡片等图片视图使用。
    func cacheThumbnail(for sceneID: String, variantIndex: Int = 0) async {
        guard let fileName = thumbnailCacheFileName(for: sceneID, variantIndex: variantIndex),
              !caching.contains("thumb_\(fileName)"),
              let remoteURL = thumbnailURL(for: sceneID, variantIndex: variantIndex) else { return }

        let destination = thumbnailCacheDirectory.appendingPathComponent(fileName)
        guard !fm.fileExists(atPath: destination.path) else { return }

        caching.insert("thumb_\(fileName)")
        defer { caching.remove("thumb_\(fileName)") }
        do {
            let (data, _) = try await URLSession.shared.data(from: remoteURL)
            try data.write(to: destination, options: .atomic)
            if let image = UIImage(data: data) {
                thumbnailCache[fileName] = image
            }
        } catch {
            print("[VideoManager] 缓存缩略图失败 \(fileName): \(error.localizedDescription)")
        }
    }

    /// 下载指定版本视频到本地缓存
    func cacheAsset(for sceneID: String, variantIndex: Int) async {
        guard let fileName = videoCacheFileName(for: sceneID, variantIndex: variantIndex) else {
            print("📀 [VideoManager] cacheAsset 跳过: 无法获取文件名 (\(sceneID), \(variantIndex))")
            return
        }
        let remoteURL = videoURL(for: sceneID, variantIndex: variantIndex)
        print("📀 [VideoManager] cacheAsset 开始: fileName=\(fileName), remoteURL=\(remoteURL?.absoluteString ?? "nil"), isCaching=\(caching.contains(fileName))")
        guard !caching.contains(fileName),
              let videoURL = remoteURL else {
            print("📀 [VideoManager] cacheAsset 跳过: fileName=\(fileName) (已在下载中或无远程URL)")
            return
        }

        let videoDestination = videoCacheDirectory.appendingPathComponent(fileName)
        guard !fm.fileExists(atPath: videoDestination.path) else {
            print("📀 [VideoManager] cacheAsset 跳过: 本地已存在 \(fileName)")
            return
        }

        caching.insert(fileName)
        defer { caching.remove(fileName) }
        await cacheThumbnail(for: sceneID, variantIndex: variantIndex)

        do {
            print("📀 [VideoManager] 开始下载视频: \(videoURL)")
            let (data, response) = try await URLSession.shared.data(from: videoURL)
            let httpStatus = (response as? HTTPURLResponse)?.statusCode ?? -1
            print("📀 [VideoManager] 视频下载完成: fileName=\(fileName), httpStatus=\(httpStatus), dataSize=\(data.count) bytes")
            try data.write(to: videoDestination, options: .atomic)
            print("📀 [VideoManager] 视频已写入: \(fileName)")
        } catch {
            print("📀 [VideoManager] 缓存视频失败 \(fileName): \(error)")
        }
    }

    // MARK: - 磁盘缓存目录

    private var videoCacheDirectory: URL {
        let dir = fm.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SceneVideos", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private var thumbnailCacheDirectory: URL {
        let dir = fm.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SceneThumbnails", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    // MARK: - 清理

    func clearCache() {
        thumbnailCache.removeAll()
        try? fm.removeItem(at: videoCacheDirectory)
        try? fm.removeItem(at: thumbnailCacheDirectory)
    }
}
