//
//  SoundItem.swift
//  NatureSound
//
//  Created by egbert on 2026/7/1.
//

import SwiftUI

// MARK: - 声音分类
struct SoundCategory: RawRepresentable, CaseIterable, Identifiable, Hashable {
    let rawValue: String
    let icon: String

    var id: String { rawValue }

    init(rawValue: String, icon: String) {
        self.rawValue = rawValue
        self.icon = icon
    }

    init?(rawValue: String) {
        guard let category = Self.allCases.first(where: { $0.rawValue == rawValue }) else { return nil }
        self = category
    }

    static let all = SoundCategory(rawValue: "精选", icon: "sparkles")
    static let water = SoundCategory(rawValue: "水流", icon: "drop.fill")
    static let weather = SoundCategory(rawValue: "天气", icon: "cloud.rain.fill")
    static let bird = SoundCategory(rawValue: "鸟鸣", icon: "bird.fill")
    static let insect = SoundCategory(rawValue: "虫鸣", icon: "ant.fill")
    static let fire = SoundCategory(rawValue: "火焰", icon: "flame.fill")
    static let zen = SoundCategory(rawValue: "禅意", icon: "bell.fill")
    static let forest = SoundCategory(rawValue: "森林", icon: "leaf.fill")
    static let ambient = SoundCategory(rawValue: "氛围", icon: "sparkles")

    static var allCases: [SoundCategory] { SoundLibrary.categories }
}

// MARK: - 声音项
struct SoundItem: Identifiable, Hashable {
    let id: String
    let name: String
    let icon: String
    let category: SoundCategory
    let color: Color
    let description: String
    let fileName: String

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: SoundItem, rhs: SoundItem) -> Bool { lhs.id == rhs.id }

    // MARK: - 声音特性分类（用于空间音频声像分配和频率管理）

    /// 环境基底声：雨、风、水流、火焰、雪等连续铺底声景，空间音频模式下居中分布。
    var isAmbientBase: Bool {
        switch category {
        case .water, .weather, .fire, .forest:
            return true
        // 氛围类中的连续背景声
        default:
            return id == "night" || id == "grass_sway"
        }
    }

    /// 低频强力声：含有大量低频能量的声音，叠加时需要高通滤波以避免掩盖其他声音。
    var needsHighPassFilter: Bool {
        switch id {
        case "thunderstorm", "heavy_rain", "blizzard", "cold_wind", "waterfall", "flying_waterfall":
            return true
        default:
            return false
        }
    }
}

// MARK: - 声音配置数据模型
private struct SoundConfiguration: Decodable {
    let categories: [SoundCategoryConfiguration]
}

private struct SoundCategoryConfiguration: Decodable {
    let id: String
    let icon: String
    let soundIDs: [String]?
    let sounds: [SoundItemConfiguration]
}

private struct SoundItemConfiguration: Decodable {
    let id: String
    let name: String
    let icon: String
    let color: String
    let description: String
    let fileName: String
}

// MARK: - 声音配置库
private enum SoundLibrary {
    static let configuration: SoundConfiguration = loadConfiguration()

    static let categories: [SoundCategory] = configuration.categories.map {
        SoundCategory(rawValue: $0.id, icon: $0.icon)
    }

    static let sounds: [SoundItem] = configuration.categories.flatMap { categoryConfiguration in
        let category = SoundCategory(rawValue: categoryConfiguration.id, icon: categoryConfiguration.icon)
        return categoryConfiguration.sounds.map { item in
            SoundItem(
                id: item.id,
                name: item.name,
                icon: item.icon,
                category: category,
                color: Color(hex: item.color),
                description: item.description,
                fileName: item.fileName
            )
        }
    }

    static let featuredSoundIDs: [String] = configuration.categories.first { $0.id == SoundCategory.all.rawValue }?.soundIDs ?? []

    private static func loadConfiguration() -> SoundConfiguration {
        guard let url = Bundle.main.url(forResource: "sounds", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            assertionFailure("未找到 sounds.json")
            return SoundConfiguration(categories: [])
        }

        do {
            return try JSONDecoder().decode(SoundConfiguration.self, from: data)
        } catch {
            assertionFailure("解析 sounds.json 失败: \(error.localizedDescription)")
            return SoundConfiguration(categories: [])
        }
    }
}

// MARK: - 自然声音库（使用真实 .m4a 音频文件）
extension SoundItem {
    static let allSounds: [SoundItem] = SoundLibrary.sounds

    static func sounds(for category: SoundCategory) -> [SoundItem] {
        if category == .all {
            let soundsByID = Dictionary(uniqueKeysWithValues: allSounds.map { ($0.id, $0) })
            return SoundLibrary.featuredSoundIDs.compactMap { soundsByID[$0] }
        }
        return allSounds.filter { $0.category == category }
    }
}
