import Foundation
import Combine

// MARK: - WorldTides API Response

private struct WorldTideResponse: Codable {
    let status: Int?
    let heights: [HeightDatum]?
    let error: String?
}

private struct HeightDatum: Codable {
    let dt: Int
    let date: String
    let height: Double
}

/// 潮汐データを管理するサービス
class TideService: ObservableObject {
    @Published var tideInfo: TideInfo?
    @Published var isLoading = false
    @Published var error: String?

    private var cache: [String: TideInfo] = [:]  // 日付ごとにキャッシュ

    // 横浜の座標
    private let yokohamaLat = 35.4437
    private let yokohamaLon = 139.6380

    /// 指定日の潮汐情報を取得
    func fetchTides(for date: Date, location: TideLocation) async {
        let cacheKey = dateString(date)

        // キャッシュがあれば利用
        if let cached = cache[cacheKey] {
            await MainActor.run {
                self.tideInfo = cached
            }
            return
        }

        await MainActor.run {
            self.isLoading = true
            self.error = nil
        }

        do {
            let baseURL = "https://www.worldtides.info/api/v3"

            // JST で指定日の 00:00:00 ～ 23:59:59 をUTCタイムスタンプに変換
            var jstCal = Calendar(identifier: .gregorian)
            jstCal.timeZone = TimeZone(identifier: "Asia/Tokyo")!

            let dateComponents = jstCal.dateComponents([.year, .month, .day], from: date)
            guard let dayStartJST = jstCal.date(from: dateComponents) else {
                throw URLError(.badURL)
            }

            // JST 00:00 = UTC 前日の 15:00
            // JST 23:59:59 = UTC その日の 14:59:59
            // 確実にカバーするため、前日の UTC 00:00 から翌日の UTC 23:59 まで取得
            let dayBeforeJST = jstCal.date(byAdding: .day, value: -1, to: dayStartJST)!
            let dayAfterJST = jstCal.date(byAdding: .day, value: 1, to: dayStartJST)!

            let startTime = Int(dayBeforeJST.timeIntervalSince1970)
            let endTime = Int(dayAfterJST.addingTimeInterval(86400).timeIntervalSince1970)

            var components = URLComponents(string: baseURL)!
            components.queryItems = [
                URLQueryItem(name: "heights", value: ""),
                URLQueryItem(name: "begin", value: String(startTime)),
                URLQueryItem(name: "end", value: String(endTime)),
                URLQueryItem(name: "lat", value: String(yokohamaLat)),
                URLQueryItem(name: "lon", value: String(yokohamaLon)),
                URLQueryItem(name: "key", value: Config.worldTidesAPIKey)
            ]

            guard let url = components.url else {
                throw URLError(.badURL)
            }

            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }

            let decoded = try JSONDecoder().decode(WorldTideResponse.self, from: data)

            guard let status = decoded.status, status == 200 else {
                throw NSError(domain: "TideService", code: -1, userInfo: [NSLocalizedDescriptionKey: decoded.error ?? "API returned an error"])
            }

            guard let heights = decoded.heights, !heights.isEmpty else {
                throw NSError(domain: "TideService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No tidal height data returned"])
            }

            // 潮位データを TidePoint に変換
            var tidePoints: [TidePoint] = []
            for datum in heights {
                let pointTime = Date(timeIntervalSince1970: TimeInterval(datum.dt))
                tidePoints.append(TidePoint(time: pointTime, height: datum.height, type: nil))
            }

            // 極値（満潮・干潮）を検出
            var extrema: [TidePoint] = []
            for i in 1..<(tidePoints.count - 1) {
                let prev = tidePoints[i - 1].height
                let curr = tidePoints[i].height
                let next = tidePoints[i + 1].height

                if curr > prev && curr > next {
                    extrema.append(TidePoint(time: tidePoints[i].time, height: curr, type: .high))
                } else if curr < prev && curr < next {
                    extrema.append(TidePoint(time: tidePoints[i].time, height: curr, type: .low))
                }
            }

            // TideInfo を構築
            let moonInfo = TideCalculator.moonPhase(for: date)
            let tideInfo = TideInfo(
                date: date,
                location: location,
                points: tidePoints + extrema,
                moonPhase: moonInfo.phase,
                moonPhaseName: moonInfo.name,
                moonAge: moonInfo.age
            )

            // キャッシュに保存
            self.cache[cacheKey] = tideInfo

            await MainActor.run {
                self.isLoading = false
                self.tideInfo = tideInfo
                self.error = nil
            }
        } catch let error as URLError {
            await MainActor.run {
                self.isLoading = false
                self.error = "潮汐データ取得エラー: \(error.localizedDescription)"
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.error = "潮汐データ取得エラー: \(error.localizedDescription)"
            }
        }
    }

    /// キャッシュをクリア
    func clearCache() {
        cache.removeAll()
    }

    private func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: date)
    }
}
