import Foundation
import Combine

/// 潮汐データ管理サービス
/// 優先順位: JMA公式推算テキスト → TideCalculator（調和分潮、オフライン時フォールバック）
@MainActor
class TideService: ObservableObject {
    @Published var tideInfo: TideInfo?
    @Published var isLoading = false
    @Published var error: String?

    private var cache: [String: TideInfo] = [:]
    private let loader = JMATideLoader.shared

    func fetchTides(for date: Date, location: TideLocation) async {
        let cacheKey = dateString(date) + "_" + location.rawValue
        if let cached = cache[cacheKey] {
            self.tideInfo = cached
            return
        }

        self.isLoading = true
        self.error = nil

        // 1) JMA公式データを試みる
        if let stn = location.jmaStationCode {
            do {
                if let day = try await loader.dayData(stationCode: stn, date: date) {
                    let info = makeTideInfo(from: day, date: date, location: location)
                    cache[cacheKey] = info
                    self.tideInfo = info
                    self.isLoading = false
                    return
                }
            } catch {
                self.error = "JMA取得失敗: \(error.localizedDescription)"
            }
        }

        // 2) フォールバック: 自作調和潮位計算
        let computed = TideCalculator.calculate(for: date, location: location)
        cache[cacheKey] = computed
        self.tideInfo = computed
        self.isLoading = false
    }

    func clearCache() {
        cache.removeAll()
        Task { await loader.clearMemoryCache() }
    }

    // MARK: - JMADayData → TideInfo 変換

    private func makeTideInfo(from day: JMADayData,
                              date: Date,
                              location: TideLocation) -> TideInfo {
        var jst = Calendar(identifier: .gregorian)
        jst.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let dayStart = jst.date(from: DateComponents(
            timeZone: TimeZone(identifier: "Asia/Tokyo"),
            year: day.year, month: day.month, day: day.day,
            hour: 0, minute: 0, second: 0))!

        // 代用局（久里浜・湘南）のみ振幅補正を適用
        let mult = location.needsHeightCorrection ? location.heightMultiplier : 1.0

        // 毎時24点 → 10分刻み線形補間（145点: 0:00〜24:00）
        var hourly = day.hourlyHeights.map { Double($0) / 100.0 * mult }
        hourly.append(hourly.last ?? 0)  // index 24（24時 = 翌0時）用

        var chartPoints: [TidePoint] = []
        chartPoints.reserveCapacity(145)
        for i in 0...144 {
            let hf = Double(i) / 6.0
            let h0 = Int(floor(hf))
            let frac = hf - Double(h0)
            let h1 = min(h0 + 1, hourly.count - 1)
            let height = hourly[h0] * (1.0 - frac) + hourly[h1] * frac
            let t = dayStart.addingTimeInterval(Double(i) * 600)
            chartPoints.append(TidePoint(time: t, height: height, type: nil))
        }

        // JMA公式の満潮・干潮をそのまま極値点として採用
        var extrema: [TidePoint] = []
        for h in day.highTides {
            let t = jst.date(bySettingHour: h.hour, minute: h.minute, second: 0, of: dayStart)!
            extrema.append(TidePoint(time: t,
                                     height: Double(h.cm) / 100.0 * mult,
                                     type: .high))
        }
        for l in day.lowTides {
            let t = jst.date(bySettingHour: l.hour, minute: l.minute, second: 0, of: dayStart)!
            extrema.append(TidePoint(time: t,
                                     height: Double(l.cm) / 100.0 * mult,
                                     type: .low))
        }

        let moon = TideCalculator.moonPhase(for: date)
        return TideInfo(
            date: date,
            location: location,
            points: chartPoints + extrema,
            moonPhase: moon.phase,
            moonPhaseName: moon.name,
            moonAge: moon.age
        )
    }

    // MARK: - Helpers

    private func dateString(_ date: Date) -> String {
        var jst = Calendar(identifier: .gregorian)
        jst.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let c = jst.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d%02d%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
