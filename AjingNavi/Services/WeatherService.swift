import Foundation
import Combine
import WeatherKit
import CoreLocation

// MARK: - Data Models

struct SeaTemperaturePoint: Identifiable {
    let id = UUID()
    let date: Date
    let temp: Double
    let isForecast: Bool
}

struct WeatherData {
    let temperature: Double
    let feelsLike: Double
    let humidity: Int
    let windSpeed: Double     // m/s
    let windGust: Double      // m/s
    let windDeg: Int          // 度
    let description: String
    let icon: String
    let visibility: Double    // km
    let pressure: Double      // hPa

    var windDirectionName: String {
        let dirs = ["北","北北東","北東","東北東","東","東南東","南東","南南東",
                    "南","南南西","南西","西南西","西","西北西","北西","北北西"]
        let index = Int((Double(windDeg) + 11.25) / 22.5) % 16
        return dirs[index]
    }

    var weatherEmoji: String { WeatherManager.emoji(for: icon) }

    var fishingWindRating: String {
        if windSpeed < 3.0 { return "最適" }
        if windSpeed < 6.0 { return "良好" }
        if windSpeed < 10.0 { return "普通" }
        return "強風注意"
    }
}

struct ForecastItem: Identifiable {
    let id = UUID()
    let date: Date
    let tempMax: Double
    let tempMin: Double
    let description: String
    let icon: String
    let windSpeed: Double
    let windGust: Double
    let precipitation: Double // mm

    var dayOfWeek: String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "ja_JP")
        fmt.dateFormat = "E"
        return fmt.string(from: date)
    }

    var dateLabel: String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "ja_JP")
        fmt.dateFormat = "M/d"
        return fmt.string(from: date)
    }

    var weatherEmoji: String { WeatherManager.emoji(for: icon) }
}

struct HourlyForecastItem: Identifiable {
    let id = UUID()
    let date: Date
    let temp: Double
    let windSpeed: Double
    let windGust: Double
    let windDeg: Int
    let description: String
    let icon: String
    let precipitation: Double // mm

    var hourLabel: String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "ja_JP")
        fmt.dateFormat = "H時"
        return fmt.string(from: date)
    }

    var windDirectionName: String {
        let dirs = ["北","北北東","北東","東北東","東","東南東","南東","南南東",
                    "南","南南西","南西","西南西","西","西北西","北西","北北西"]
        let index = Int((Double(windDeg) + 11.25) / 22.5) % 16
        return dirs[index]
    }

    var weatherEmoji: String { WeatherManager.emoji(for: icon) }
}

// MARK: - WeatherManager (Apple WeatherKit)

@MainActor
class WeatherManager: ObservableObject {
    @Published var current: WeatherData?
    @Published var forecast: [ForecastItem] = []
    @Published var hourlyForecast: [HourlyForecastItem] = []
    @Published var fullHourlyForecast: [HourlyForecastItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var dataSource = "取得前"
    @Published var seaTemperature: [SeaTemperaturePoint] = []

    @Published var selectedSpot: FishingSpot

    var locationName: String { selectedSpot.name }

    private let wkService = WeatherService.shared

    init(spot: FishingSpot = FishingSpot.yokohamaYokosuka[0]) {
        self.selectedSpot = spot
    }

    func fetchWeather() async {
        isLoading = true
        errorMessage = nil

        let lat = selectedSpot.coordinate.latitude
        let lon = selectedSpot.coordinate.longitude
        let location = CLLocation(latitude: lat, longitude: lon)

        async let seaTempTask: Void = fetchSeaTemperature(lat: lat, lon: lon)

        do {
            let weather = try await wkService.weather(
                for: location,
                including: .current, .hourly, .daily
            )
            self.current            = parseCurrentWeather(weather.0)
            self.hourlyForecast     = parseHourlyForecast(weather.1)
            self.fullHourlyForecast = parseAllHourlyForecast(weather.1)
            self.forecast           = parseDailyForecast(weather.2)
            self.dataSource         = "Apple Weather"
        } catch {
            let nsErr = error as NSError
            print("⚠️ WK domain=\(nsErr.domain) code=\(nsErr.code)")
            do {
                try await fetchOpenMeteo(lat: lat, lon: lon)
            } catch {
                errorMessage = "天気の取得に失敗しました"
                loadSampleData()
            }
        }

        _ = await seaTempTask
        isLoading = false
    }

    // MARK: - Parse Current

    private func parseCurrentWeather(_ w: CurrentWeather) -> WeatherData {
        let windMs   = w.wind.speed.converted(to: .metersPerSecond).value
        let gustMs   = w.wind.gust?.converted(to: .metersPerSecond).value ?? 0
        let windDeg  = Int(w.wind.direction.value)
        let (desc, icon) = Self.weatherInfo(condition: w.condition, isDaylight: w.isDaylight)

        return WeatherData(
            temperature: w.temperature.converted(to: .celsius).value,
            feelsLike:   w.apparentTemperature.converted(to: .celsius).value,
            humidity:    Int(w.humidity * 100),
            windSpeed:   windMs,
            windGust:    gustMs,
            windDeg:     windDeg,
            description: desc,
            icon:        icon,
            visibility:  w.visibility.converted(to: .kilometers).value,
            pressure:    w.pressure.converted(to: .hectopascals).value
        )
    }

    // MARK: - Parse Hourly

    private func parseHourlyForecast(_ forecast: Forecast<HourWeather>) -> [HourlyForecastItem] {
        let now = Date()
        return forecast
            .filter { $0.date >= now.addingTimeInterval(-1800) }
            .prefix(24)
            .map { h in
                let windMs  = h.wind.speed.converted(to: .metersPerSecond).value
                let gustMs  = h.wind.gust?.converted(to: .metersPerSecond).value ?? 0
                let windDeg = Int(h.wind.direction.value)
                let precip  = h.precipitationAmount.converted(to: .millimeters).value
                let hour    = Calendar.current.component(.hour, from: h.date)
                let (desc, icon) = Self.weatherInfo(condition: h.condition, isDaylight: hour >= 6 && hour < 18)
                return HourlyForecastItem(
                    date:          h.date,
                    temp:          h.temperature.converted(to: .celsius).value,
                    windSpeed:     windMs,
                    windGust:      gustMs,
                    windDeg:       windDeg,
                    description:   desc,
                    icon:          icon,
                    precipitation: precip
                )
            }
    }

    // 全時間帯（5日分）を返す — 日付別時間別予報の表示用
    private func parseAllHourlyForecast(_ forecast: Forecast<HourWeather>) -> [HourlyForecastItem] {
        let now = Date()
        return forecast
            .filter { $0.date >= now.addingTimeInterval(-1800) }
            .map { h in
                let windMs  = h.wind.speed.converted(to: .metersPerSecond).value
                let gustMs  = h.wind.gust?.converted(to: .metersPerSecond).value ?? 0
                let windDeg = Int(h.wind.direction.value)
                let precip  = h.precipitationAmount.converted(to: .millimeters).value
                let hour    = Calendar.current.component(.hour, from: h.date)
                let (desc, icon) = Self.weatherInfo(condition: h.condition, isDaylight: hour >= 6 && hour < 18)
                return HourlyForecastItem(
                    date:          h.date,
                    temp:          h.temperature.converted(to: .celsius).value,
                    windSpeed:     windMs,
                    windGust:      gustMs,
                    windDeg:       windDeg,
                    description:   desc,
                    icon:          icon,
                    precipitation: precip
                )
            }
    }

    // MARK: - Parse Daily

    private func parseDailyForecast(_ forecast: Forecast<DayWeather>) -> [ForecastItem] {
        return Array(forecast.prefix(7)).map { d in
            let windMs  = d.wind.speed.converted(to: .metersPerSecond).value
            let gustMs  = d.wind.gust?.converted(to: .metersPerSecond).value ?? 0
            let precip  = d.precipitationAmount.converted(to: .millimeters).value
            let (desc, icon) = Self.weatherInfo(condition: d.condition, isDaylight: true)
            return ForecastItem(
                date:          d.date,
                tempMax:       d.highTemperature.converted(to: .celsius).value,
                tempMin:       d.lowTemperature.converted(to: .celsius).value,
                description:   desc,
                icon:          icon,
                windSpeed:     windMs,
                windGust:      gustMs,
                precipitation: precip
            )
        }
    }

    // MARK: - WeatherCondition → 日本語・アイコン

    static func weatherInfo(condition: WeatherCondition, isDaylight: Bool) -> (String, String) {
        let s = isDaylight ? "d" : "n"
        switch condition {
        case .clear:                    return ("快晴",          "01\(s)")
        case .mostlyClear:              return ("晴れ",          "01\(s)")
        case .partlyCloudy:             return ("晴れ時々曇り",   "02\(s)")
        case .mostlyCloudy:             return ("曇りがち",       "03\(s)")
        case .cloudy:                   return ("曇り",          "04\(s)")
        case .foggy, .haze, .smoky:     return ("霧・もや",      "50\(s)")
        case .drizzle:                  return ("霧雨",          "10\(s)")
        case .rain:                     return ("雨",            "10\(s)")
        case .heavyRain:                return ("大雨",          "09\(s)")
        case .sunShowers:               return ("小雨",          "10\(s)")
        case .isolatedThunderstorms,
             .scatteredThunderstorms,
             .thunderstorms:            return ("雷雨",          "11\(s)")
        case .snow, .flurries:          return ("雪",            "13\(s)")
        case .heavySnow, .blizzard:     return ("大雪",          "13\(s)")
        case .sleet, .freezingDrizzle,
             .freezingRain, .wintryMix: return ("みぞれ",        "13\(s)")
        case .breezy, .windy:           return ("強風",          "02\(s)")
        case .hot:                      return ("猛暑",          "01\(s)")
        case .blowingDust:              return ("砂嵐",          "50\(s)")
        default:                        return ("曇り",          "03\(s)")
        }
    }

    static func emoji(for icon: String) -> String {
        if icon.contains("01") { return "☀️" }
        if icon.contains("02") { return "⛅" }
        if icon.contains("03") { return "🌥" }
        if icon.contains("04") { return "☁️" }
        if icon.contains("09") { return "🌧" }
        if icon.contains("10") { return "🌦" }
        if icon.contains("11") { return "⛈" }
        if icon.contains("13") { return "❄️" }
        if icon.contains("50") { return "🌫" }
        return "🌤"
    }

    // MARK: - Open-Meteo フォールバック

    private func fetchOpenMeteo(lat: Double, lon: Double) async throws {
        var comps = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        comps.queryItems = [
            .init(name: "latitude",  value: "\(lat)"),
            .init(name: "longitude", value: "\(lon)"),
            .init(name: "current",   value: "temperature_2m,apparent_temperature,weather_code,wind_speed_10m,wind_direction_10m,wind_gusts_10m,surface_pressure,visibility"),
            .init(name: "hourly",    value: "temperature_2m,weather_code,wind_speed_10m,wind_direction_10m,wind_gusts_10m,precipitation"),
            .init(name: "daily",     value: "weather_code,temperature_2m_max,temperature_2m_min,wind_speed_10m_max,wind_gusts_10m_max,precipitation_sum"),
            .init(name: "wind_speed_unit", value: "ms"),
            .init(name: "timezone",  value: "Asia/Tokyo"),
            .init(name: "forecast_days", value: "7"),
        ]
        let (data, _) = try await URLSession.shared.data(from: comps.url!)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        // Current
        if let c = json["current"] as? [String: Any] {
            let code    = c["weather_code"] as? Int ?? 0
            let hour    = Calendar.current.component(.hour, from: Date())
            let isDay   = hour >= 6 && hour < 18
            let (desc, icon) = Self.wmoInfo(code: code, isDay: isDay)
            let visM    = c["visibility"] as? Double ?? 10000
            self.current = WeatherData(
                temperature: c["temperature_2m"]      as? Double ?? 0,
                feelsLike:   c["apparent_temperature"] as? Double ?? 0,
                humidity:    0,
                windSpeed:   c["wind_speed_10m"]       as? Double ?? 0,
                windGust:    c["wind_gusts_10m"]       as? Double ?? 0,
                windDeg:     c["wind_direction_10m"]   as? Int    ?? 0,
                description: desc,
                icon:        icon,
                visibility:  visM / 1000.0,
                pressure:    c["surface_pressure"]     as? Double ?? 1013
            )
        }

        // Hourly (next 24h)
        if let h = json["hourly"] as? [String: Any] {
            let times   = h["time"]               as? [String] ?? []
            let temps   = h["temperature_2m"]     as? [Double] ?? []
            let codes   = h["weather_code"]       as? [Int]    ?? []
            let winds   = h["wind_speed_10m"]     as? [Double] ?? []
            let windDir = h["wind_direction_10m"] as? [Int]    ?? []
            let gusts   = h["wind_gusts_10m"]     as? [Double] ?? []
            let precips = h["precipitation"]      as? [Double] ?? []

            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd'T'HH:mm"
            fmt.timeZone = TimeZone(identifier: "Asia/Tokyo")
            let now = Date()

            var items: [HourlyForecastItem] = []
            var fullItems: [HourlyForecastItem] = []
            for i in 0..<times.count {
                guard let date = fmt.date(from: times[i]), date >= now.addingTimeInterval(-1800) else { continue }
                let hourComp = Calendar.current.component(.hour, from: date)
                let code = i < codes.count ? codes[i] : 0
                let (desc, icon) = Self.wmoInfo(code: code, isDay: hourComp >= 6 && hourComp < 18)
                let item = HourlyForecastItem(
                    date:          date,
                    temp:          i < temps.count   ? temps[i]   : 0,
                    windSpeed:     i < winds.count   ? winds[i]   : 0,
                    windGust:      i < gusts.count   ? gusts[i]   : 0,
                    windDeg:       i < windDir.count ? windDir[i] : 0,
                    description:   desc,
                    icon:          icon,
                    precipitation: i < precips.count ? precips[i] : 0
                )
                fullItems.append(item)
                if items.count < 24 { items.append(item) }
            }
            self.hourlyForecast     = items
            self.fullHourlyForecast = fullItems
        }

        // Daily
        if let d = json["daily"] as? [String: Any] {
            let times    = d["time"]                  as? [String] ?? []
            let codes    = d["weather_code"]          as? [Int]    ?? []
            let maxTemps = d["temperature_2m_max"]    as? [Double] ?? []
            let minTemps = d["temperature_2m_min"]    as? [Double] ?? []
            let winds    = d["wind_speed_10m_max"]    as? [Double] ?? []
            let gusts    = d["wind_gusts_10m_max"]    as? [Double] ?? []
            let precips  = d["precipitation_sum"]     as? [Double] ?? []

            let dateFmt = DateFormatter()
            dateFmt.dateFormat = "yyyy-MM-dd"
            dateFmt.timeZone = TimeZone(identifier: "Asia/Tokyo")

            self.forecast = times.prefix(7).enumerated().compactMap { (i, t) -> ForecastItem? in
                guard let date = dateFmt.date(from: t) else { return nil }
                let code = i < codes.count ? codes[i] : 0
                let (desc, icon) = Self.wmoInfo(code: code, isDay: true)
                return ForecastItem(
                    date:          date,
                    tempMax:       i < maxTemps.count ? maxTemps[i] : 0,
                    tempMin:       i < minTemps.count ? minTemps[i] : 0,
                    description:   desc,
                    icon:          icon,
                    windSpeed:     i < winds.count   ? winds[i]   : 0,
                    windGust:      i < gusts.count   ? gusts[i]   : 0,
                    precipitation: i < precips.count ? precips[i] : 0
                )
            }
        }

        self.dataSource = "Open-Meteo (ECMWF)"
        self.errorMessage = nil
    }

    // MARK: - 海水温取得 (Open-Meteo Marine API)

    private func fetchSeaTemperature(lat: Double, lon: Double) async {
        var comps = URLComponents(string: "https://marine-api.open-meteo.com/v1/marine")!
        comps.queryItems = [
            .init(name: "latitude",               value: "\(lat)"),
            .init(name: "longitude",              value: "\(lon)"),
            .init(name: "hourly",                 value: "sea_surface_temperature"),
            .init(name: "past_days",              value: "7"),
            .init(name: "forecast_days",          value: "3"),
            .init(name: "timezone",               value: "Asia/Tokyo"),
        ]
        guard let url = comps.url,
              let (data, _) = try? await URLSession.shared.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let hourly = json["hourly"] as? [String: Any],
              let times  = hourly["time"] as? [String],
              let temps  = hourly["sea_surface_temperature"] as? [Any] else { return }

        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd'T'HH:mm"
        fmt.timeZone = TimeZone(identifier: "Asia/Tokyo")
        let now = Date()

        // 6時間刻みでサンプリング（240点 → 40点）してグラフを見やすくする
        var points: [SeaTemperaturePoint] = []
        for (i, timeStr) in times.enumerated() {
            guard i % 6 == 0,
                  let date = fmt.date(from: timeStr) else { continue }
            let raw = temps[i]
            let temp: Double
            if let d = raw as? Double { temp = d }
            else if let n = raw as? NSNull { _ = n; continue }
            else { continue }
            points.append(SeaTemperaturePoint(date: date, temp: temp, isForecast: date > now))
        }
        self.seaTemperature = points
    }

    // WMO Weather Code → (日本語説明, アイコンID)
    static func wmoInfo(code: Int, isDay: Bool) -> (String, String) {
        let s = isDay ? "d" : "n"
        switch code {
        case 0:        return ("快晴",          "01\(s)")
        case 1:        return ("晴れ",          "01\(s)")
        case 2:        return ("晴れ時々曇り",   "02\(s)")
        case 3:        return ("曇り",          "04\(s)")
        case 45, 48:   return ("霧・もや",      "50\(s)")
        case 51, 53:   return ("霧雨",          "10\(s)")
        case 55:       return ("濃い霧雨",       "10\(s)")
        case 61, 63:   return ("雨",            "10\(s)")
        case 65:       return ("大雨",          "09\(s)")
        case 66, 67:   return ("みぞれ",        "13\(s)")
        case 71, 73:   return ("雪",            "13\(s)")
        case 75, 77:   return ("大雪",          "13\(s)")
        case 80, 81:   return ("にわか雨",       "10\(s)")
        case 82:       return ("激しいにわか雨", "09\(s)")
        case 85, 86:   return ("雪のにわか",     "13\(s)")
        case 95:       return ("雷雨",          "11\(s)")
        case 96, 99:   return ("雷雨（ひょう）", "11\(s)")
        default:       return ("曇り",          "03\(s)")
        }
    }

    // MARK: - サンプルデータ（フォールバック）

    func loadSampleData() {
        dataSource = "サンプルデータ（通信エラー）"

        current = WeatherData(
            temperature: 18.5, feelsLike: 17.2, humidity: 65,
            windSpeed: 4.2, windGust: 7.5, windDeg: 225,
            description: "晴れ", icon: "01d", visibility: 10.0, pressure: 1013
        )

        let cal = Calendar.current
        let icons = ["01d","02d","10d","04d","01d","02d","01d"]
        let descs = ["晴れ","晴れ時々曇り","雨","曇り","晴れ","晴れ時々曇り","晴れ"]
        forecast = (0..<7).map { d in
            ForecastItem(
                date: cal.date(byAdding: .day, value: d, to: Date())!,
                tempMax: Double.random(in: 17...22), tempMin: Double.random(in: 12...16),
                description: descs[d], icon: icons[d],
                windSpeed: Double.random(in: 2...8), windGust: Double.random(in: 4...12),
                precipitation: d == 2 ? 8.0 : 0
            )
        }

        let windDegs = [225,200,180,210,195,220,230,215,200,190,210,205,
                        220,215,225,200,195,210,225,230,215,200,205,215]
        let hIcons   = ["01d","01d","02d","02d","02n","03n","03n","02n",
                        "01n","01n","01d","01d","02d","02d","01d","01d",
                        "02d","03d","02d","01d","01n","01n","02n","02n"]
        hourlyForecast = (0..<24).map { i in
            HourlyForecastItem(
                date: Date().addingTimeInterval(Double(i) * 3600),
                temp: Double.random(in: 16...21),
                windSpeed: Double.random(in: 2...7),
                windGust:  Double.random(in: 4...12),
                windDeg:   windDegs[i],
                description: "晴れ", icon: hIcons[i],
                precipitation: i == 8 ? 1.5 : 0
            )
        }
    }
}
