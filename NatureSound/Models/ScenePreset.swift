//
//  ScenePreset.swift
//  NatureSound
//
//  Created by egbert on 2026/7/1.
//

import SwiftUI

// MARK: - 场景标签
enum SceneTag: String, CaseIterable, Identifiable, Decodable {
    case sleep    = "助眠"
    case focus    = "专注"
    case relax    = "放松"
    case nature   = "自然"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .focus:  return "brain.head.profile.fill"
        case .relax:  return "leaf.fill"
        case .sleep:  return "moon.stars.fill"
        case .nature: return "mountain.2.fill"
        }
    }
}

// MARK: - 场景配置数据模型
private struct SceneConfiguration: Decodable {
    let scenes: [ScenePreset]
    let featuredSceneIDs: [String]
}

// MARK: - 预设场景
struct ScenePreset: Identifiable, Decodable {
    let id: String
    let name: String
    let icon: String
    let description: String
    let color: Color
    let soundIDs: [String]
    let volumes: [String: Float]
    let tags: [SceneTag]

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case icon
        case description
        case colorHex
        case soundIDs
        case volumes
        case tags
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        icon = try container.decode(String.self, forKey: .icon)
        description = try container.decode(String.self, forKey: .description)
        color = Color(hex: try container.decode(String.self, forKey: .colorHex))
        soundIDs = try container.decode([String].self, forKey: .soundIDs)
        volumes = try container.decode([String: Float].self, forKey: .volumes)
        tags = try container.decode([SceneTag].self, forKey: .tags)
    }
}

extension ScenePreset {
    private static let configuration: SceneConfiguration = loadConfiguration()

    static let allPresets: [ScenePreset] = configuration.scenes

    static let featuredPresets: [ScenePreset] = configuration.featuredSceneIDs.compactMap { id in
        allPresets.first { $0.id == id }
    }

    // MARK: - 场景配置加载

    private static func loadConfiguration() -> SceneConfiguration {
        guard let url = Bundle.main.url(forResource: "scenes", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            assertionFailure("未找到 scenes.json")
            return SceneConfiguration(scenes: [], featuredSceneIDs: [])
        }

        do {
            return try JSONDecoder().decode(SceneConfiguration.self, from: data)
        } catch {
            assertionFailure("解析 scenes.json 失败: \(error.localizedDescription)")
            return SceneConfiguration(scenes: [], featuredSceneIDs: [])
        }
    }
}

// MARK: - 用户自定义场景
struct UserScene: Codable, Identifiable {
    let id: String
    var name: String
    var soundIDs: [String]
    var volumes: [String: Float]
    var createdAt: Date

    init(name: String, soundIDs: [String], volumes: [String: Float]) {
        self.id = UUID().uuidString
        self.name = name
        self.soundIDs = soundIDs
        self.volumes = volumes
        self.createdAt = Date()
    }
}
