//
//  SoundItem.swift
//  NatureSound
//
//  Created by egbert on 2026/7/1.
//

import SwiftUI

// MARK: - 声音分类
enum SoundCategory: String, CaseIterable, Identifiable {
    case all      = "全部"
    case water    = "水流"
    case weather  = "天气"
    case bird     = "鸟鸣"
    case insect   = "虫鸣"
    case fire     = "火焰"
    case zen      = "禅意"
    case forest   = "森林"
    case ambient  = "氛围"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .all:     return "square.grid.2x2"
        case .water:   return "drop.fill"
        case .weather: return "cloud.rain.fill"
        case .bird:    return "bird.fill"
        case .insect:  return "ant.fill"
        case .fire:    return "flame.fill"
        case .zen:     return "bell.fill"
        case .forest:  return "leaf.fill"
        case .ambient: return "sparkles"
        }
    }
}

// MARK: - 声音项
struct SoundItem: Identifiable, Hashable {
    let id: String
    let name: String
    let icon: String
    let category: SoundCategory
    let color: Color
    let description: String

    /// 用于生成音调的频率参数（合成音用）
    let baseFrequency: Double
    let harmonics: [Double]

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: SoundItem, rhs: SoundItem) -> Bool { lhs.id == rhs.id }
}

// MARK: - 30 种自然声音库
extension SoundItem {
    static let allSounds: [SoundItem] = [
        // 水流类 (5)
        SoundItem(id: "stream", name: "山间溪流", icon: "drop.fill", category: .water, color: Color(hex: "4FC3F7"), description: "清澈的溪水潺潺流过鹅卵石", baseFrequency: 220, harmonics: [1.0, 0.5, 0.25, 0.12]),
        SoundItem(id: "ocean", name: "海浪拍岸", icon: "water.waves", category: .water, color: Color(hex: "0288D1"), description: "海浪轻柔地拍打着沙滩", baseFrequency: 110, harmonics: [1.0, 0.7, 0.4, 0.2]),
        SoundItem(id: "waterfall", name: "飞流瀑布", icon: "arrow.down.to.line", category: .water, color: Color(hex: "0097A7"), description: "磅礴的瀑布从高处倾泻而下", baseFrequency: 165, harmonics: [1.0, 0.8, 0.6, 0.4, 0.2]),
        SoundItem(id: "fountain", name: "喷泉水声", icon: "drop.triangles.fill", category: .water, color: Color(hex: "4DD0E1"), description: "花园中喷泉的水花跳跃声", baseFrequency: 330, harmonics: [1.0, 0.3, 0.15]),
        SoundItem(id: "drip", name: "水滴落叶", icon: "drop.degreesign.fill", category: .water, color: Color(hex: "80DEEA"), description: "晨露滴落在翠绿的叶片上", baseFrequency: 880, harmonics: [1.0, 0.2, 0.05]),

        // 天气类 (5)
        SoundItem(id: "rain", name: "细雨绵绵", icon: "cloud.rain.fill", category: .weather, color: Color(hex: "78909C"), description: "窗外下着淅淅沥沥的小雨", baseFrequency: 200, harmonics: [1.0, 0.6, 0.3, 0.15]),
        SoundItem(id: "thunder", name: "雷声滚滚", icon: "cloud.bolt.fill", category: .weather, color: Color(hex: "546E7A"), description: "远处天边传来低沉的雷鸣", baseFrequency: 55, harmonics: [1.0, 0.9, 0.7, 0.5, 0.3]),
        SoundItem(id: "hail", name: "冰雹敲窗", icon: "cloud.hail.fill", category: .weather, color: Color(hex: "B0BEC5"), description: "冰雹轻敲屋顶和窗户", baseFrequency: 1200, harmonics: [1.0, 0.4, 0.1]),
        SoundItem(id: "wind", name: "山谷清风", icon: "wind", category: .weather, color: Color(hex: "90A4AE"), description: "风穿过山谷发出的呼啸声", baseFrequency: 150, harmonics: [1.0, 0.5, 0.3]),
        SoundItem(id: "snowfall", name: "雪落无声", icon: "snowflake", category: .weather, color: Color(hex: "CFD8DC"), description: "雪花簌簌飘落在寂静的夜晚", baseFrequency: 3000, harmonics: [1.0, 0.1, 0.02]),

        // 鸟鸣类 (4)
        SoundItem(id: "songbird", name: "百灵鸟鸣", icon: "bird.fill", category: .bird, color: Color(hex: "FFB74D"), description: "清晨百灵鸟婉转悠扬的歌声", baseFrequency: 1760, harmonics: [1.0, 0.5, 0.25]),
        SoundItem(id: "owl", name: "猫头鹰语", icon: "moon.stars.fill", category: .bird, color: Color(hex: "8D6E63"), description: "夜晚森林深处猫头鹰的低鸣", baseFrequency: 440, harmonics: [1.0, 0.6, 0.3]),
        SoundItem(id: "seagull", name: "海鸥翱翔", icon: "bird", category: .bird, color: Color(hex: "FFE082"), description: "海鸥在碧蓝海面上的鸣叫", baseFrequency: 2200, harmonics: [1.0, 0.4, 0.15]),
        SoundItem(id: "cuckoo", name: "布谷鸟啼", icon: "leaf.arrow.circlepath", category: .bird, color: Color(hex: "A1887F"), description: "春天田野里布谷鸟的啼叫", baseFrequency: 1320, harmonics: [1.0, 0.5, 0.2]),

        // 虫鸣类 (3)
        SoundItem(id: "cricket", name: "蟋蟀夜曲", icon: "ant.fill", category: .insect, color: Color(hex: "AED581"), description: "夏夜草丛中蟋蟀的鸣唱", baseFrequency: 4000, harmonics: [1.0, 0.3, 0.1]),
        SoundItem(id: "cicada", name: "蝉鸣盛夏", icon: "sun.max.fill", category: .insect, color: Color(hex: "DCE775"), description: "正午树上此起彼伏的蝉鸣", baseFrequency: 3500, harmonics: [1.0, 0.5, 0.2]),
        SoundItem(id: "firefly", name: "萤火虫夜", icon: "sparkle", category: .insect, color: Color(hex: "CE93D8"), description: "夏夜田野中萤火虫飞舞的柔和氛围", baseFrequency: 300, harmonics: [1.0, 0.3, 0.1]),

        // 火焰类 (3)
        SoundItem(id: "campfire", name: "篝火噼啪", icon: "flame.fill", category: .fire, color: Color(hex: "FF7043"), description: "野外篝火木柴燃烧的噼啪声", baseFrequency: 180, harmonics: [1.0, 0.7, 0.5, 0.3]),
        SoundItem(id: "fireplace", name: "壁炉温暖", icon: "fireplace.fill", category: .fire, color: Color(hex: "FF8A65"), description: "冬日壁炉里柴火温柔燃烧", baseFrequency: 140, harmonics: [1.0, 0.6, 0.3, 0.15]),
        SoundItem(id: "candle", name: "烛火摇曳", icon: "light.max", category: .fire, color: Color(hex: "FFAB91"), description: "安静房间里烛火轻轻摇曳", baseFrequency: 250, harmonics: [1.0, 0.2, 0.05]),

        // 禅意类 (4)
        SoundItem(id: "temple", name: "古寺木鱼", icon: "circle.circle.fill", category: .zen, color: Color(hex: "FFD54F"), description: "寺院中木鱼声声，节奏沉稳安宁", baseFrequency: 680, harmonics: [1.0, 0.3, 0.1]),
        SoundItem(id: "bell", name: "古寺钟声", icon: "bell.fill", category: .zen, color: Color(hex: "FFC107"), description: "悠远绵长的寺庙晨钟暮鼓", baseFrequency: 261.6, harmonics: [1.0, 0.7, 0.5, 0.3, 0.15]),
        SoundItem(id: "bowl", name: "颂钵共鸣", icon: "circle.circle.fill", category: .zen, color: Color(hex: "FFE082"), description: "铜钵敲击后持续的共鸣声", baseFrequency: 432, harmonics: [1.0, 0.9, 0.7, 0.5]),
        SoundItem(id: "chime", name: "风铃叮当", icon: "wind", category: .zen, color: Color(hex: "FFF176"), description: "微风吹动檐下风铃的清脆声", baseFrequency: 1046, harmonics: [1.0, 0.5, 0.2]),

        // 森林类 (3)
        SoundItem(id: "forest", name: "森林漫步", icon: "tree.fill", category: .forest, color: Color(hex: "66BB6A"), description: "脚踩落叶穿行在幽静森林", baseFrequency: 300, harmonics: [1.0, 0.5, 0.3, 0.15]),
        SoundItem(id: "bamboo", name: "竹林风韵", icon: "leaf.fill", category: .forest, color: Color(hex: "81C784"), description: "风吹竹林沙沙作响", baseFrequency: 500, harmonics: [1.0, 0.4, 0.2, 0.1]),
        SoundItem(id: "leaves", name: "秋叶沙沙", icon: "wind", category: .forest, color: Color(hex: "A5D6A7"), description: "秋风吹过树梢落叶飞舞", baseFrequency: 400, harmonics: [1.0, 0.3, 0.1]),

        // 氛围类 (3)
        SoundItem(id: "cave", name: "山洞回声", icon: "mountain.2.fill", category: .ambient, color: Color(hex: "7E57C2"), description: "空旷山洞中神秘的回响", baseFrequency: 100, harmonics: [1.0, 0.8, 0.6, 0.5, 0.4, 0.3]),
        SoundItem(id: "night", name: "静谧星空", icon: "moon.stars.fill", category: .ambient, color: Color(hex: "5C6BC0"), description: "万籁俱寂的夜晚中微弱的自然声", baseFrequency: 60, harmonics: [1.0, 0.3, 0.1]),
        SoundItem(id: "garden", name: "花园清晨", icon: "camera.macro", category: .ambient, color: Color(hex: "EC407A"), description: "清晨花园里露水与花香的氛围", baseFrequency: 350, harmonics: [1.0, 0.4, 0.2, 0.1]),
    ]

    static func sounds(for category: SoundCategory) -> [SoundItem] {
        category == .all ? allSounds : allSounds.filter { $0.category == category }
    }
}
