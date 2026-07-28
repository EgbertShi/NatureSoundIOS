//
//  VideoManager.swift
//  NatureSound
//
//  Created by egbert on 2026/7/15.
//

import SwiftUI
import AVFoundation
import os

// MARK: - videos.json 数据模型

private struct VideoIndex: Decodable {
    let baseURL: String
    let videos: [VideoEntry]
}

private struct VideoEntry: Decodable {
    let sceneID: String
    let name: String
    let videos: [VideoAsset]

    private enum CodingKeys: String, CodingKey {
        case sceneID, name, videos
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sceneID = try container.decode(String.self, forKey: .sceneID)
        name = try container.decode(String.self, forKey: .name)
        // videos 字段允许缺失（场景暂未配置视频素材时），缺失时视为空数组
        videos = try container.decodeIfPresent([VideoAsset].self, forKey: .videos) ?? []
    }
}

private struct VideoAsset: Decodable {
    let videoPath: String
    let thumbnailPath: String
    let fileSize: Int
}

// MARK: - 场景视频管理器
// 负责解析场景视频/缩略图索引（videos.json），并提供 OSS 远程 URL
// 缓存文件名直接取自服务端路径中的文件名，保证本地与远程一一对应
//
// 标记为 @Observable 且限定在 @MainActor：
// 1. cachedThumbnailImage/cachedVideoURL 等方法依赖的缓存状态发生变化时，
//    SwiftUI 视图（FeaturedSceneCard、ImmersiveVideoBackground 等）能够自动感知并重新渲染，
//    不再依赖视图自身脆弱的本地 @State 计数器（首次安装、无本地缓存时最容易触发此问题）。
// 2. 所有缓存字典的读写都在主线程串行执行，避免并发下载任务同时命中 VideoManager 造成的竞态。
@MainActor
@Observable
final class VideoManager {
    /// 每个 sceneID 对应的资源条目
    private var entries: [String: VideoEntry] = [:]
    /// OSS 基础 URL
    private var baseURL: String = ""

    /// 内存缓存：缩略图
    private var thumbnailCache: [String: UIImage] = [:]
    /// 正在下载中的资源缓存任务（用远程文件名作为 key，避免重复下载）
    private var caching: Set<String> = []

    /// 缓存版本号：每次磁盘/内存缓存发生变化时递增，
    /// 作为 @Observable 的可追踪存储属性，驱动依赖 cachedThumbnailImage/cachedVideoURL 的视图刷新。
    private(set) var cacheVersion = 0

    /// 视频文件落盘的最小合法字节数。
    /// OSS 返回 404/403 时通常会返回一段 XML 错误页面（几百字节到几 KB），
    /// 合法的视频文件通常在 100 KB 以上。用此阈值过滤掉错误响应。
    private static let minimumVideoBytes = 100_000

    /// 缩略图落盘的最小合法字节数（合法的 JPEG 至少也有几 KB）。
    private static let minimumThumbnailBytes = 1_000

    private let fm = FileManager.default

    init() {
        loadVideoIndex()
    }

    // MARK: - 索引加载（从 bundle 内的 videos.json）

    private func loadVideoIndex() {
        guard let url = Bundle.main.url(forResource: "videos", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            AppLogger.video.error("未找到 videos.json")
            return
        }
        do {
            let index = try JSONDecoder().decode(VideoIndex.self, from: data)
            baseURL = index.baseURL
            for entry in index.videos {
                entries[entry.sceneID] = entry
            }
        } catch {
            AppLogger.video.error("解析 videos.json 失败: \(error.localizedDescription, privacy: .public)")
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

    /// 是否存在该场景的**有效**视频/缩略图资源。
    /// fileSize == 0 表示 OSS 上尚未上传实际文件，视为无资源。
    func hasAsset(for sceneID: String) -> Bool {
        guard let entry = entries[sceneID] else { return false }
        return entry.videos.contains { $0.fileSize > 0 }
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
        // 读取 cacheVersion 使该方法参与 @Observable 追踪：
        // 缓存更新后递增 cacheVersion 会让依赖本方法结果的视图重新求值。
        _ = cacheVersion
        guard let fileName = thumbnailCacheFileName(for: sceneID, variantIndex: variantIndex) else { return nil }
        if let image = thumbnailCache[fileName] { return image }
        let url = thumbnailCacheDirectory.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: url),
              data.count >= Self.minimumThumbnailBytes,
              let image = UIImage(data: data) else {
            // 磁盘上存在但不是合法图片（可能是 404 错误页面），清理掉
            if fm.fileExists(atPath: url.path) {
                try? fm.removeItem(at: url)
                AppLogger.video.info("清理无效缩略图缓存: \(fileName, privacy: .public)")
            }
            return nil
        }
        thumbnailCache[fileName] = image
        return image
    }

    /// 仅返回已落盘且有效的视频 URL，播放器绝不直接访问远程 OSS 地址。
    func cachedVideoURL(for sceneID: String, variantIndex: Int) -> URL? {
        // 读取 cacheVersion 使该方法参与 @Observable 追踪，详见 cachedThumbnailImage 注释。
        _ = cacheVersion
        guard let fileName = videoCacheFileName(for: sceneID, variantIndex: variantIndex) else { return nil }
        let url = videoCacheDirectory.appendingPathComponent(fileName)
        // 检查文件是否存在且大小合理（过滤掉 404 错误页面等脏数据）
        guard let attrs = try? fm.attributesOfItem(atPath: url.path),
              let fileSize = attrs[.size] as? Int,
              fileSize >= Self.minimumVideoBytes else {
            // 存在但太小，是脏数据，清理掉
            if fm.fileExists(atPath: url.path) {
                try? fm.removeItem(at: url)
                AppLogger.video.info("清理无效视频缓存: \(fileName, privacy: .public)（文件过小）")
            }
            return nil
        }
        return url
    }

    /// 缓存指定版本的缩略图，供卡片等图片视图使用。
    func cacheThumbnail(for sceneID: String, variantIndex: Int = 0) async {
        // fileSize == 0 的条目不尝试下载
        guard let asset = videoAsset(for: sceneID, variantIndex: variantIndex),
              asset.fileSize > 0 else { return }
        guard let fileName = thumbnailCacheFileName(for: sceneID, variantIndex: variantIndex),
              !caching.contains("thumb_\(fileName)"),
              let remoteURL = thumbnailURL(for: sceneID, variantIndex: variantIndex) else { return }

        let destination = thumbnailCacheDirectory.appendingPathComponent(fileName)
        guard !fm.fileExists(atPath: destination.path) else { return }

        caching.insert("thumb_\(fileName)")
        defer { caching.remove("thumb_\(fileName)") }
        do {
            let (data, response) = try await URLSession.shared.data(from: remoteURL)
            // 校验 HTTP 状态码
            let httpStatus = (response as? HTTPURLResponse)?.statusCode ?? -1
            guard (200...299).contains(httpStatus) else {
                AppLogger.video.error("缩略图下载返回非 2xx 状态码: \(httpStatus), 文件: \(fileName, privacy: .public)")
                return
            }
            // 校验数据是否为合法图片
            guard data.count >= Self.minimumThumbnailBytes,
                  let image = UIImage(data: data) else {
                AppLogger.video.error("缩略图数据无效: 文件: \(fileName, privacy: .public), 大小: \(data.count)")
                return
            }
            try data.write(to: destination, options: .atomic)
            thumbnailCache[fileName] = image
            cacheVersion += 1
        } catch {
            AppLogger.video.error("缓存缩略图失败 \(fileName, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    /// 下载指定版本视频到本地缓存
    func cacheAsset(for sceneID: String, variantIndex: Int) async {
        // fileSize == 0 的条目不尝试下载
        guard let asset = videoAsset(for: sceneID, variantIndex: variantIndex),
              asset.fileSize > 0 else {
            AppLogger.video.debug("跳过视频缓存：资源未上传（\(sceneID, privacy: .public), \(variantIndex)）")
            return
        }
        guard let fileName = videoCacheFileName(for: sceneID, variantIndex: variantIndex) else {
            AppLogger.video.error("跳过视频缓存：无法获取文件名（\(sceneID, privacy: .public), \(variantIndex)）")
            return
        }
        let remoteURL = videoURL(for: sceneID, variantIndex: variantIndex)
        AppLogger.video.debug("开始视频缓存: \(fileName, privacy: .public), 正在缓存: \(self.caching.contains(fileName))")
        guard !caching.contains(fileName),
              let videoURL = remoteURL else {
            AppLogger.video.debug("跳过视频缓存: \(fileName, privacy: .public)（正在下载或无远程地址）")
            return
        }

        let videoDestination = videoCacheDirectory.appendingPathComponent(fileName)
        // 检查本地缓存：存在且大小合理才跳过
        if let attrs = try? fm.attributesOfItem(atPath: videoDestination.path),
           let existingSize = attrs[.size] as? Int,
           existingSize >= Self.minimumVideoBytes {
            AppLogger.video.debug("跳过视频缓存：本地已有有效缓存 \(fileName, privacy: .public)（\(existingSize) bytes）")
            return
        }
        // 清理可能存在的脏数据
        if fm.fileExists(atPath: videoDestination.path) {
            try? fm.removeItem(at: videoDestination)
            AppLogger.video.info("清理无效本地视频缓存: \(fileName, privacy: .public)")
        }

        caching.insert(fileName)
        defer { caching.remove(fileName) }
        await cacheThumbnail(for: sceneID, variantIndex: variantIndex)

        do {
            AppLogger.video.debug("开始下载视频: \(fileName, privacy: .public)")
            let (data, response) = try await URLSession.shared.data(from: videoURL)
            let httpStatus = (response as? HTTPURLResponse)?.statusCode ?? -1
            AppLogger.video.debug("视频下载完成: \(fileName, privacy: .public), 状态码: \(httpStatus), 大小: \(data.count) bytes")
            // 校验 HTTP 状态码
            guard (200...299).contains(httpStatus) else {
                AppLogger.video.error("视频下载返回非 2xx 状态码 \(httpStatus)，不写入磁盘")
                return
            }
            // 校验数据大小是否合理
            guard data.count >= Self.minimumVideoBytes else {
                AppLogger.video.error("视频数据过小（\(data.count) bytes），疑似错误响应，不写入磁盘")
                return
            }
            try data.write(to: videoDestination, options: .atomic)
            cacheVersion += 1
            AppLogger.video.info("视频已写入缓存: \(fileName, privacy: .public)")
        } catch {
            AppLogger.video.error("缓存视频失败 \(fileName, privacy: .public): \(error.localizedDescription, privacy: .public)")
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

    // MARK: - Now Playing 封面图片

    /// 获取指定场景的高分辨率缩略图用于锁屏 Now Playing 封面。
    /// 优先从内存缓存获取，其次从磁盘缓存加载。
    /// 返回的图片将作为 MPMediaItemArtwork 展示在锁屏界面。
    func nowPlayingArtwork(for sceneID: String, variantIndex: Int = 0) -> UIImage? {
        return cachedThumbnailImage(for: sceneID, variantIndex: variantIndex)
    }

    /// 异步获取场景封面图：先尝试本地缓存，缓存未命中则从远程下载后返回。
    func fetchNowPlayingArtwork(for sceneID: String, variantIndex: Int = 0) async -> UIImage? {
        // 先看本地缓存
        if let image = cachedThumbnailImage(for: sceneID, variantIndex: variantIndex) {
            return image
        }
        // 下载缩略图并缓存
        await cacheThumbnail(for: sceneID, variantIndex: variantIndex)
        return cachedThumbnailImage(for: sceneID, variantIndex: variantIndex)
    }

    // MARK: - 清理

    func clearCache() {
        thumbnailCache.removeAll()
        try? fm.removeItem(at: videoCacheDirectory)
        try? fm.removeItem(at: thumbnailCacheDirectory)
        cacheVersion += 1
    }
}
