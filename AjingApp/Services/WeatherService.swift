import Foundation

struct WeatherData {
    let temperature: Double
    let feelsLike: Double
    let humidity: Int
    let windSpeed: Double
    let windDeg: Int
    let description: String
    let icon: String
    let visibility: Double
    let pressure: Int

    var windDirectionName: String {
        let directions = ["北", "北北東", "北東", "東北東", "東", "東南東", "南東", "南南東",
                          "南", "南南西", "南西", "西南西", "西", "西北西", "北西", "北北西"]
        let index = Int((Double(windDeg) + 11.25) / 22.5) % 16
        return directions[index]
    }

    var weatherEmoji: String {
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

    var fishingWindRating: String {
        if windSpeed < 3.0 { return "最適" }
        if windSpeed < 6.0 { return "良好" }
        if windSpeed < 10.0 { return "普通" }
        return "強風注意"
    }
}

struct ForecastItem {
    let date: Date
    let tempMax: Double
    let tempMin: Double
    let description: String
    let icon: String
    let windSpeed: Double
    let precipitation: Double

    var dayOfWeek: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }

    var weatherEmoji: String {
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
}

@MainActor
class WeatherService: ObservableObject {
    @Published var current: WeatherData?
    @Published var forecast: [ForecastItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // Replace with your OpenWeatherMap API key
    private let apiKey = "YOUR_OPENWEATHERMAP_API_KEY"
    private let yokohamaLat = 35.4437
    private let yokohamaLon = 139.6380

    func fetchWeather() async {
        guard apiKey != "YOUR_OPENWEATHERMAP_API_KEY" else {
            loadSampleData()
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            async let currentData = fetchCurrentWeather()
            async let forecastData = fetchForecast()
            let (cur, fore) = try await (currentData, forecastData)
            self.current = cur
            self.forecast = fore
        } catch {
            errorMessage = "天気情報の取得に失敗しました: \(error.localizedDescription)"
            loadSampleData()
        }

        isLoading = false
    }

    private func fetchCurrentWeather() async throws -> WeatherData {
        let urlStr = "https://api.openweathermap.org/data/2.5/weather?lat=\(yokohamaLat)&lon=\(yokohamaLon)&appid=\(apiKey)&units=metric&lang=ja"
        guard let url = URL(string: urlStr) else { throw URLError(.badURL) }

        let (data, _) = try await URLSession.shared.data(from: url)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        let main = json["main"] as! [String: Any]
        let wind = json["wind"] as! [String: Any]
        let weather = (json["weather"] as! [[String: Any]]).first!

        return WeatherData(
            temperature: main["temp"] as! Double,
            feelsLike: main["feels_like"] as! Double,
            humidity: main["humidity"] as! Int,
            windSpeed: wind["speed"] as! Double,
            windDeg: wind["deg"] as? Int ?? 0,
            description: weather["description"] as! String,
            icon: weather["icon"] as! String,
            visibility: (json["visibility"] as? Double ?? 10000) / 1000.0,
            pressure: main["pressure"] as! Int
        )
    }

    private func fetchForecast() async throws -> [ForecastItem] {
        let urlStr = "https://api.openweathermap.org/data/2.5/forecast?lat=\(yokohamaLat)&lon=\(yokohamaLon)&appid=\(apiKey)&units=metric&lang=ja&cnt=40"
        guard let url = URL(string: urlStr) else { throw URLError(.badURL) }

        let (data, _) = try await URLSession.shared.data(from: url)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let list = json["list"] as! [[String: Any]]

        // Group by day and extract daily summary
        var dailyData: [String: [String: Any]] = [:]
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        for item in list {
            let dt = Date(timeIntervalSince1970: item["dt"] as! Double)
            let dayKey = formatter.string(from: dt)
            if dailyData[dayKey] == nil {
                dailyData[dayKey] = item
            }
        }

        return dailyData.sorted(by: { $0.key < $1.key }).prefix(5).compactMap { (key, item) in
            guard let dt = formatter.date(from: key) else { return nil }
            let main = item["main"] as! [String: Any]
            let weather = (item["weather"] as! [[String: Any]]).first!
            let wind = item["wind"] as? [String: Any]
            let rain = item["rain"] as? [String: Any]

            return ForecastItem(
                date: dt,
                tempMax: main["temp_max"] as? Double ?? main["temp"] as! Double,
                tempMin: main["temp_min"] as? Double ?? main["temp"] as! Double,
                description: weather["description"] as! String,
                icon: weather["icon"] as! String,
                windSpeed: wind?["speed"] as? Double ?? 0,
                precipitation: rain?["3h"] as? Double ?? 0
            )
        }
    }

    func loadSampleData() {
        current = WeatherData(
            temperature: 18.5,
            feelsLike: 17.2,
            humidity: 65,
            windSpeed: 4.2,
            windDeg: 225,
            description: "晴れ",
            icon: "01d",
            visibility: 10.0,
            pressure: 1013
        )

        let calendar = Calendar.current
        forecast = (0..<5).map { day in
            let date = calendar.date(byAdding: .day, value: day, to: Date())!
            let icons = ["01d", "02d", "10d", "04d", "01d"]
            let descs = ["晴れ", "晴れ時々曇り", "雨", "曇り", "晴れ"]
            return ForecastItem(
                date: date,
                tempMax: Double.random(in: 17...22),
                tempMin: Double.random(in: 12...16),
                description: descs[day],
                icon: icons[day],
                windSpeed: Double.random(in: 2...8),
                precipitation: day == 2 ? 5.0 : 0
            )
        }
    }
}
