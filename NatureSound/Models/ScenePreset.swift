//
//  ScenePreset.swift
//  NatureSound
//
//  Created by egbert on 2026/7/1.
//

import SwiftUI

// MARK: - 预设场景
struct ScenePreset: Identifiable {
    let id: String
    let name: String
    let icon: String
    let description: String
    let color: Color
    let soundIDs: [String]
    let volumes: [String: Float]
}

extension ScenePreset {
    static let allPresets: [ScenePreset] = [
        ScenePreset(id: "rainy_reading", name: "雨夜读书", icon: "book.fill", description: "细雨、雷声与壁炉的温暖组合", color: Color(hex: "78909C"), soundIDs: ["rain", "thunder", "fireplace"], volumes: ["rain": 0.8, "thunder": 0.4, "fireplace": 0.6]),
        ScenePreset(id: "forest_meditation", name: "森林冥想", icon: "leaf.fill", description: "溪流、鸟鸣与竹林的深度放松", color: Color(hex: "66BB6A"), soundIDs: ["stream", "songbird", "bamboo", "bowl"], volumes: ["stream": 0.7, "songbird": 0.4, "bamboo": 0.5, "bowl": 0.3]),
        ScenePreset(id: "ocean_night", name: "海边夜晚", icon: "moon.stars.fill", description: "海浪、清风与蟋蟀的静谧海岸", color: Color(hex: "0288D1"), soundIDs: ["ocean", "wind", "cricket"], volumes: ["ocean": 0.8, "wind": 0.4, "cricket": 0.3]),
        ScenePreset(id: "zen_temple", name: "禅意寺院", icon: "bell.fill", description: "钟声、颂钵与木鱼的冥想之境", color: Color(hex: "FFC107"), soundIDs: ["bell", "bowl", "temple"], volumes: ["bell": 0.5, "bowl": 0.5, "temple": 0.4]),
        ScenePreset(id: "campfire_night", name: "篝火露营", icon: "flame.fill", description: "篝火、虫鸣与星空下的安宁", color: Color(hex: "FF7043"), soundIDs: ["campfire", "cricket", "night", "owl"], volumes: ["campfire": 0.8, "cricket": 0.4, "night": 0.5, "owl": 0.3]),
        ScenePreset(id: "spring_garden", name: "春日花园", icon: "camera.macro", description: "鸟语花香、溪流潺潺的清晨", color: Color(hex: "EC407A"), soundIDs: ["garden", "songbird", "stream", "chime"], volumes: ["garden": 0.6, "songbird": 0.5, "stream": 0.5, "chime": 0.3]),
        ScenePreset(id: "deep_focus", name: "深度专注", icon: "brain.head.profile.fill", description: "白噪音与自然声的专注背景", color: Color(hex: "5C6BC0"), soundIDs: ["rain", "fireplace", "wind"], volumes: ["rain": 0.6, "fireplace": 0.5, "wind": 0.3]),
        ScenePreset(id: "summer_noon", name: "盛夏午后", icon: "sun.max.fill", description: "蝉鸣、微风中的慵懒时光", color: Color(hex: "DCE775"), soundIDs: ["cicada", "wind", "leaves"], volumes: ["cicada": 0.5, "wind": 0.6, "leaves": 0.4]),
        ScenePreset(id: "winter_night", name: "冬夜暖炉", icon: "snowflake", description: "壁炉、风声与雪夜的温暖庇护", color: Color(hex: "90A4AE"), soundIDs: ["fireplace", "wind", "snowfall"], volumes: ["fireplace": 0.8, "wind": 0.3, "snowfall": 0.4]),
        ScenePreset(id: "cave_explore", name: "洞穴探秘", icon: "mountain.2.fill", description: "山洞回声与水滴的神秘地下世界", color: Color(hex: "7E57C2"), soundIDs: ["cave", "drip", "stream"], volumes: ["cave": 0.7, "drip": 0.5, "stream": 0.3]),
        ScenePreset(id: "lake_dawn", name: "湖畔晨曦", icon: "sun.haze.fill", description: "喷泉、鸟鸣与风铃的清新早晨", color: Color(hex: "4DD0E1"), soundIDs: ["fountain", "songbird", "chime", "garden"], volumes: ["fountain": 0.6, "songbird": 0.5, "chime": 0.3, "garden": 0.4]),
        ScenePreset(id: "starry_night", name: "星空露营", icon: "moon.stars.fill", description: "篝火、萤火虫与猫头鹰的浪漫夜晚", color: Color(hex: "5C6BC0"), soundIDs: ["campfire", "firefly", "owl", "night"], volumes: ["campfire": 0.7, "firefly": 0.5, "owl": 0.3, "night": 0.4]),
        ScenePreset(id: "waterfall_zen", name: "瀑布禅修", icon: "arrow.down.to.line", description: "瀑布、颂钵与风声的力量冥想", color: Color(hex: "0097A7"), soundIDs: ["waterfall", "bowl", "wind"], volumes: ["waterfall": 0.7, "bowl": 0.4, "wind": 0.3]),
        ScenePreset(id: "rainy_cafe", name: "雨日咖啡馆", icon: "cup.and.saucer.fill", description: "细雨、壁炉与风铃的慵懒午后", color: Color(hex: "8D6E63"), soundIDs: ["rain", "candle", "chime", "wind"], volumes: ["rain": 0.6, "candle": 0.3, "chime": 0.2, "wind": 0.3]),
    ]
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
