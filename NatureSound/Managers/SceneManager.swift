//
//  SceneManager.swift
//  NatureSound
//
//  Created by egbert on 2026/7/1.
//

import SwiftUI

@Observable
final class SceneManager {
    private let userDefaultsKey = "NatureSound_UserScenes"

    var userScenes: [UserScene] = []

    init() { loadScenes() }

    func saveCurrentScene(name: String, soundIDs: [String], volumes: [String: Float]) {
        userScenes.append(UserScene(name: name, soundIDs: soundIDs, volumes: volumes))
        persistScenes()
    }

    func deleteScene(_ scene: UserScene) {
        userScenes.removeAll { $0.id == scene.id }
        persistScenes()
    }

    func clearAllScenes() {
        userScenes.removeAll()
        persistScenes()
    }

    func renameScene(_ scene: UserScene, to newName: String) {
        if let idx = userScenes.firstIndex(where: { $0.id == scene.id }) {
            userScenes[idx].name = newName
            persistScenes()
        }
    }

    private func persistScenes() {
        if let data = try? JSONEncoder().encode(userScenes) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }

    private func loadScenes() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let scenes = try? JSONDecoder().decode([UserScene].self, from: data) else { return }
        userScenes = scenes
    }
}
