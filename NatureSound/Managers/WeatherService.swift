//
//  WeatherService.swift
//  NatureSound
//
//  Created by egbert on 2026/7/1.
//

import Foundation
import CoreLocation
import SwiftUI
import os

// MARK: - 天气状况
enum WeatherCondition: String, Hashable {
    case clear
    case cloudy
    case rain
    case heavyRain
    case thunderstorm
    case snow
    case fog
    case windy

    var icon: String {
        switch self {
        case .clear:        return "sun.max.fill"
        case .cloudy:       return "cloud.fill"
        case .rain:         return "cloud.rain.fill"
        case .heavyRain:    return "cloud.bolt.rain.fill"
        case .thunderstorm: return "cloud.bolt.rain.fill"
        case .snow:         return "snowflake"
        case .fog:          return "cloud.fog.fill"
        case .windy:        return "wind"
        }
    }

    /// 天气类型的中文名称
    var displayName: String {
        switch self {
        case .clear:        return "晴"
        case .cloudy:       return "多云"
        case .rain:         return "小雨"
        case .heavyRain:    return "大雨"
        case .thunderstorm: return "雷雨"
        case .snow:         return "雪"
        case .fog:          return "雾"
        case .windy:        return "大风"
        }
    }

    /// 天气体感描述文案
    var feelsDescription: String {
        switch self {
        case .clear:        return "天朗气清，适合放松"
        case .cloudy:       return "云层轻覆，柔光恬静"
        case .rain:         return "细雨轻洒，润物无声"
        case .heavyRain:    return "大雨倾盆，聆听自然"
        case .thunderstorm: return "雷声隆隆，感受力量"
        case .snow:         return "白雪皑皑，万籁俱寂"
        case .fog:          return "雾气氤氲，朦胧如梦"
        case .windy:        return "清风徐来，心旷神怡"
        }
    }
}

// MARK: - 时段
enum DayPeriod: String {
    case morning
    case afternoon
    case evening
    case night

    static func current(at date: Date = .now) -> DayPeriod {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<12:  return .morning
        case 12..<17: return .afternoon
        case 17..<21: return .evening
        default:      return .night
        }
    }

    // MARK: 氛围图片

    var ambianceImageName: String {
        ambianceImagePool.randomElement() ?? ambianceImagePool[0]
    }

    private var ambianceImagePool: [String] {
        switch self {
        case .morning:   return ["ambiance_morning", "ambiance_morning2", "ambiance_morning3"]
        case .afternoon: return ["ambiance_afternoon", "ambiance_afternoon2"]
        case .evening:   return ["ambiance_evening", "ambiance_evening2"]
        case .night:     return ["ambiance_night"]
        }
    }

    func ambianceImageName(weather: WeatherCondition?) -> String {
        if let weather, let specific = Self.weatherSpecificImage(weather) {
            return specific
        }
        return ambianceImageName
    }

    private static func weatherSpecificImage(_ weather: WeatherCondition) -> String? {
        switch weather {
        case .snow:                      return "ambiance_snowy"
        case .rain, .heavyRain:          return "ambiance_rainy"
        default:                         return nil
        }
    }

    // MARK: 问候语

    func greeting(weather: WeatherCondition?) -> String {
        if let weather {
            switch weather {
            case .rain, .heavyRain:  return "雨滴敲打窗棂的午后"
            case .thunderstorm:      return "雷雨交加的时光"
            case .snow:              return "雪花簇簇落下的夜晚"
            case .fog:               return "晨雾缩绕的山谷"
            case .windy:             return "风穿过树梢的午后"
            default: break
            }
        }
        switch self {
        case .morning:   return "晨光洒进窗台的早晨"
        case .afternoon: return "阳光穿过树梢的午后"
        case .evening:   return "晚霆染红天边的傍晚"
        case .night:     return "繁星点点的静谧夜晚"
        }
    }

    func subtitle(weather: WeatherCondition?) -> String {
        if let weather {
            switch weather {
            case .rain, .heavyRain:  return "听听窗外的雨声"
            case .thunderstorm:      return "感受大自然的力量"
            case .snow:              return "享受宁静的雪夜"
            case .fog:               return "朦胧中沉静心灵"
            case .windy:             return "让风声伴你入眠"
            default: break
            }
        }
        switch self {
        case .morning:   return "让自然白噪音陪伴你的新一天"
        case .afternoon: return "让自然白噪音陪伴你的专注时刻"
        case .evening:   return "在自然声中放松身心"
        case .night:     return "让自然声伴你安然入睡"
        }
    }

    // MARK: 推荐声音

    func recommendedSoundIDs(weather: WeatherCondition?) -> [String] {
        if let weather {
            switch weather {
            case .rain, .heavyRain:
                return ["rain", "stream", "fireplace"]
            case .thunderstorm:
                return ["thunderstorm", "rain", "campfire"]
            case .snow:
                return ["cold_wind", "campfire", "stove_crackle"]
            case .windy:
                return ["forest_wind", "chime", "forest_morning"]
            default: break
            }
        }
        switch self {
        case .morning:
            return ["songbird", "forest_morning", "stream"]
        case .afternoon:
            return ["cicada", "forest_wind", "stream"]
        case .evening:
            return ["cricket", "campfire", "chime"]
        case .night:
            return ["owl", "night", "cricket", "stove_crackle", "temple_bell"]
        }
    }
}

// MARK: - 天气服务
@Observable
final class WeatherService: NSObject, CLLocationManagerDelegate {
    var currentWeather: WeatherCondition?
    var temperature: Double?
    var isLoading = false

    private var lastFetchDate: Date?
    private let locationManager = CLLocationManager()

    // MARK: UserDefaults 缓存键
    private static let cacheKeyWeather = "WeatherService.cachedWeather"
    private static let cacheKeyTemp    = "WeatherService.cachedTemp"
    private static let cacheKeyDate    = "WeatherService.cachedDate"

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        AppLogger.weather.info("WeatherService 初始化")
        loadCachedWeather()
    }

    // MARK: 获取天气

    func fetchWeatherIfNeeded() {
        // 30 分钟内不重复请求
        if let last = lastFetchDate, Date.now.timeIntervalSince(last) < 1800 {
            let remaining = 1800 - Date.now.timeIntervalSince(last)
            AppLogger.weather.debug("距上次获取仅 \(Int(remaining / 60)) 分钟，跳过请求")
            return
        }

        let status = locationManager.authorizationStatus
        AppLogger.weather.info("准备获取天气，定位授权状态: \(status.rawValue) (\(status == .authorizedWhenInUse ? "whenInUse" : status == .authorizedAlways ? "always" : status == .notDetermined ? "notDetermined" : "denied/restricted"))")
        if status == .notDetermined {
            AppLogger.weather.notice("定位未授权，请求 WhenInUse 授权")
            locationManager.requestWhenInUseAuthorization()
        } else if status == .authorizedWhenInUse || status == .authorizedAlways {
            AppLogger.weather.info("开始请求定位")
            locationManager.requestLocation()
        } else {
            AppLogger.weather.warning("定位授权被拒绝或受限，无法获取天气")
        }
    }

    // MARK: CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            AppLogger.weather.warning("didUpdateLocations 收到空位置数组")
            return
        }
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        AppLogger.weather.info("获取到定位: lat=\(String(format: "%.4f", lat)), lon=\(String(format: "%.4f", lon))")
        Task { await fetchWeather(lat: lat, lon: lon) }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        AppLogger.weather.error("定位失败: \(error.localizedDescription)")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        let statusName: String = switch status {
        case .notDetermined:       "notDetermined"
        case .restricted:          "restricted"
        case .denied:              "denied"
        case .authorizedAlways:    "authorizedAlways"
        case .authorizedWhenInUse: "authorizedWhenInUse"
        @unknown default:          "unknown(\(status.rawValue))"
        }
        AppLogger.weather.info("定位授权状态变更: \(statusName)")
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            AppLogger.weather.info("授权通过，开始请求定位")
            manager.requestLocation()
        } else if status == .denied || status == .restricted {
            AppLogger.weather.warning("用户拒绝或受限定位授权，天气功能将不可用")
        }
    }

    // MARK: API 请求

    private func fetchWeather(lat: Double, lon: Double) async {
        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current=weather_code,temperature_2m&timezone=auto"
        guard let url = URL(string: urlString) else {
            AppLogger.weather.error("URL 构造失败: \(urlString)")
            return
        }

        defer { Task { @MainActor in isLoading = false } }
        isLoading = true
        AppLogger.weather.info("开始请求天气 API: \(url.absoluteString)")

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let httpResponse = response as? HTTPURLResponse {
                AppLogger.weather.debug("API 响应状态码: \(httpResponse.statusCode), 数据大小: \(data.count) bytes")
            }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let current = json["current"] as? [String: Any],
                  let weatherCode = current["weather_code"] as? Int else {
                AppLogger.weather.error("天气数据解析失败: 缺少 current/weather_code 字段")
                return
            }

            let temp = current["temperature_2m"] as? Double
            let condition = Self.mapWeatherCode(weatherCode)

            AppLogger.weather.info("天气获取成功: \(condition.displayName), \(temp.map { String(format: "%.1f", $0) } ?? "无")°C, WMO code=\(weatherCode)")

            Task { @MainActor in
                self.currentWeather = condition
                self.temperature = temp
                self.lastFetchDate = .now
                self.persistWeather()
            }
        } catch {
            AppLogger.weather.error("天气请求失败: \(error.localizedDescription)")
        }
    }

    // MARK: WMO 天气代码映射

    private static func mapWeatherCode(_ code: Int) -> WeatherCondition {
        switch code {
        case 0, 1:          return .clear
        case 2, 3:          return .cloudy
        case 45, 48:        return .fog
        case 51...55:       return .rain
        case 56...57:       return .rain
        case 61...63:       return .rain
        case 65:            return .heavyRain
        case 66...67:       return .rain
        case 71...77:       return .snow
        case 80...82:       return .heavyRain
        case 85...86:       return .snow
        case 95:            return .thunderstorm
        case 96...99:       return .thunderstorm
        default:            return .clear
        }
    }

    // MARK: 缓存

    private func persistWeather() {
        let defaults = UserDefaults.standard
        if let weather = currentWeather {
            defaults.set(weather.rawValue, forKey: Self.cacheKeyWeather)
        }
        if let temp = temperature {
            defaults.set(temp, forKey: Self.cacheKeyTemp)
        }
        defaults.set(Date.now.timeIntervalSince1970, forKey: Self.cacheKeyDate)
        AppLogger.weather.info("天气已缓存到 UserDefaults: \(self.currentWeather?.displayName ?? "无"), \(self.temperature.map { String(format: "%.1f", $0) } ?? "无")°C")
    }

    private func loadCachedWeather() {
        let defaults = UserDefaults.standard
        if let raw = defaults.string(forKey: Self.cacheKeyWeather) {
            currentWeather = WeatherCondition(rawValue: raw)
        }
        let temp = defaults.object(forKey: Self.cacheKeyTemp) as? Double
        temperature = temp

        if let cachedTimestamp = defaults.object(forKey: Self.cacheKeyDate) as? Double {
            let cachedDate = Date(timeIntervalSince1970: cachedTimestamp)
            lastFetchDate = cachedDate
            let ageMinutes = Int(Date.now.timeIntervalSince(cachedDate) / 60)
            AppLogger.weather.info("加载缓存天气: \(self.currentWeather?.displayName ?? "无"), \(self.temperature.map { String(format: "%.1f", $0) } ?? "无")°C, 缓存于 \(ageMinutes) 分钟前")
        } else {
            AppLogger.weather.info("无缓存天气记录，首次启动")
        }
    }
}
