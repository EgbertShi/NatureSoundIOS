//
//  LoopingVideoPlayer.swift
//  NatureSound
//
//  Created by egbert on 2026/7/15.
//

import SwiftUI
import AVFoundation
import UIKit

// MARK: - 循环视频播放器（SwiftUI 封装）

struct LoopingVideoPlayer: UIViewRepresentable {
    let url: URL
    let isActive: Bool
    var previewImage: UIImage?

    func makeUIView(context: Context) -> LoopingPlayerUIView {
        LoopingPlayerUIView(url: url, isActive: isActive, previewImage: previewImage)
    }

    func updateUIView(_ uiView: LoopingPlayerUIView, context: Context) {
        uiView.switchTo(url: url, previewImage: previewImage)
        uiView.setPlaying(isActive)
    }

    static func dismantleUIView(_ uiView: LoopingPlayerUIView, coordinator: ()) {
        uiView.cleanup()
    }
}

// MARK: - UIKit 视图

final class LoopingPlayerUIView: UIView {
    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var currentURL: URL?
    private var previewImageView: UIImageView?
    private var readyObservation: NSKeyValueObservation?
    private var itemObservation: NSKeyValueObservation?
    private var endObserver: NSObjectProtocol?
    private var foregroundObserver: NSObjectProtocol?
    private var hasFadedIn = false
    private var wantsPlayback = false

    init(url: URL, isActive: Bool, previewImage: UIImage? = nil) {
        super.init(frame: .zero)
        backgroundColor = .clear
        isUserInteractionEnabled = false
        setupPreviewImage(previewImage)
        setupPlayer(url: url)
        setPlaying(isActive)
        observeForeground()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer?.frame = bounds
    }

    // MARK: - 切换视频

    func switchTo(url: URL, previewImage: UIImage? = nil) {
        guard url != currentURL else { return }
        // 先用新场景的缩略图替换旧的预览图，避免旧场景画面残留导致两个场景同时可见
        if let previewImage {
            setupPreviewImage(previewImage)
        }
        setupPlayer(url: url)
        if wantsPlayback {
            player?.play()
        }
    }

    func setPlaying(_ isPlaying: Bool) {
        wantsPlayback = isPlaying
        if isPlaying {
            player?.play()
            // 视频已就绪过则直接显示，否则等 fadeIn
            if hasFadedIn { playerLayer?.opacity = 1 }
        } else {
            player?.pause()
            // 非激活时隐藏 AVPlayerLayer，防止穿透到其他视频层
            playerLayer?.opacity = 0
        }
    }

    // MARK: - 清理

    func cleanup() {
        readyObservation?.invalidate()
        readyObservation = nil
        itemObservation?.invalidate()
        itemObservation = nil
        removeEndObserver()
        removeForegroundObserver()
        player?.pause()
        player = nil
        playerLayer?.removeFromSuperlayer()
        playerLayer = nil
        currentURL = nil
        hasFadedIn = false
    }

    // MARK: - 前后台切换

    // App 从后台回到前台时，系统可能已经暂停了底层 AVPlayer（尤其是静音、
    // 无画中画的视频层），仅恢复 SwiftUI body 求值并不会让已存在的
    // AVPlayerLayer 重新播放，因此需要显式监听前台通知并按需重新 play()。
    private func observeForeground() {
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.resumeIfNeeded()
        }
    }

    private func removeForegroundObserver() {
        if let foregroundObserver {
            NotificationCenter.default.removeObserver(foregroundObserver)
            self.foregroundObserver = nil
        }
    }

    private func resumeIfNeeded() {
        guard wantsPlayback, let player else { return }
        if player.timeControlStatus != .playing {
            player.play()
        }
    }

    // MARK: - 预览图

    private func setupPreviewImage(_ image: UIImage?) {
        previewImageView?.removeFromSuperview()
        guard let image else { return }
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.frame = bounds
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(imageView)
        previewImageView = imageView
    }

    // MARK: - 播放器与循环

    private func setupPlayer(url: URL) {
        readyObservation?.invalidate()
        itemObservation?.invalidate()
        removeEndObserver()
        player?.pause()

        currentURL = url
        hasFadedIn = false

        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        player.isMuted = true
        player.automaticallyWaitsToMinimizeStalling = true

        let layer = playerLayer ?? AVPlayerLayer()
        layer.player = player
        layer.videoGravity = .resizeAspectFill
        layer.frame = bounds
        layer.opacity = 0
        if layer.superlayer == nil {
            self.layer.addSublayer(layer)
        }

        self.player = player
        playerLayer = layer
        observeReady(layer: layer, item: item)
        observeEnd(of: item)
    }

    private func observeEnd(of item: AVPlayerItem) {
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            guard let self, self.wantsPlayback else { return }
            self.player?.seek(to: .zero) { [weak self] finished in
                guard finished, self?.wantsPlayback == true else { return }
                self?.player?.play()
            }
        }
    }

    private func removeEndObserver() {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
    }

    // MARK: - 首帧就绪

    private func observeReady(layer: AVPlayerLayer, item: AVPlayerItem) {
        readyObservation = layer.observe(\.isReadyForDisplay, options: [.new]) { [weak self] layer, _ in
            guard layer.isReadyForDisplay else { return }
            DispatchQueue.main.async { self?.fadeIn() }
        }

        itemObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard item.status == .readyToPlay else { return }
            DispatchQueue.main.async { self?.fadeIn() }
        }
    }

    private func fadeIn() {
        guard let layer = playerLayer, !hasFadedIn else { return }
        hasFadedIn = true

        // 仅在需要播放时才显示，否则保持隐藏
        guard wantsPlayback else { return }

        UIView.animate(withDuration: 0.35, animations: {
            layer.opacity = 1
        }, completion: { _ in
            self.previewImageView?.removeFromSuperview()
            self.previewImageView = nil
        })
    }
}
