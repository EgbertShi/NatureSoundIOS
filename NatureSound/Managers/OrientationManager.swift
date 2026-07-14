//
//  OrientationManager.swift
//  NatureSound
//
//  Created by egbert on 2026/7/11.
//

import SwiftUI
import UIKit
internal import Combine

// MARK: - 屏幕方向管理器
class OrientationManager: ObservableObject {
    @Published var isLandscape = false

    func setLandscape() {
        isLandscape = true
        rotateDevice(to: .landscapeRight, lock: .landscapeRight)
    }

    func setPortrait() {
        isLandscape = false
        rotateDevice(to: .portrait, lock: .portrait)
    }

    /// 同步恢复竖屏（退出待机时使用，不走延迟）
    func restorePortrait() {
        isLandscape = false
        AppDelegate.orientationLock = .portrait
        UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
        UIViewController.attemptRotationToDeviceOrientation()
        if #available(iOS 16.0, *) {
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                scene.requestGeometryUpdate(UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: .portrait))
            }
        }
    }

    func toggle() { isLandscape ? setPortrait() : setLandscape() }

    private func rotateDevice(to orientation: UIInterfaceOrientation, lock: UIInterfaceOrientationMask) {
        // 1. 先解锁所有方向，否则系统会拒绝旋转请求
        AppDelegate.orientationLock = .allButUpsideDown

        // 2. 请求旋转
        UIDevice.current.setValue(orientation.rawValue, forKey: "orientation")
        UIViewController.attemptRotationToDeviceOrientation()

        if #available(iOS 16.0, *) {
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                scene.requestGeometryUpdate(UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: lock))
            }
        }

        // 3. 延迟后锁定到目标方向，防止用户手动旋转
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            AppDelegate.orientationLock = lock
        }
    }
}
