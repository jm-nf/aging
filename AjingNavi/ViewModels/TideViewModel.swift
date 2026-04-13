import Foundation
import Combine

@MainActor
class TideViewModel: ObservableObject {
    @Published var tideInfo: TideInfo?
    @Published var selectedSpot: FishingSpot = FishingSpot.yokohamaYokosuka[0]
    @Published var selectedDate: Date = Date()
    @Published var isLoading = false
    @Published var error: String?

    private let tideService = TideService()

    init(spot: FishingSpot = FishingSpot.yokohamaYokosuka[0]) {
        self.selectedSpot = spot
        recalculate()
    }

    func recalculate() {
        Task {
            await tideService.fetchTides(for: selectedDate, location: selectedSpot.tideLocation)

            DispatchQueue.main.async {
                self.tideInfo = self.tideService.tideInfo
                self.isLoading = self.tideService.isLoading
                self.error = self.tideService.error
            }
        }
    }

    func updateSpot(_ spot: FishingSpot) {
        selectedSpot = spot
        recalculate()
    }

    func updateDate(_ date: Date) {
        selectedDate = date
        recalculate()
    }

    var currentHeight: Double {
        // 現在時刻の潮位を推定（最新の取得データから補間）
        guard let points = tideInfo?.points.sorted(by: { $0.time < $1.time }),
              let first = points.first,
              let last = points.last else {
            return 0
        }

        let now = Date()
        if now < first.time { return first.height }
        if now > last.time { return last.height }

        // 直線補間
        for i in 0..<(points.count - 1) {
            if points[i].time <= now && now <= points[i + 1].time {
                let t1 = points[i].time.timeIntervalSince1970
                let t2 = points[i + 1].time.timeIntervalSince1970
                let ratio = (now.timeIntervalSince1970 - t1) / (t2 - t1)
                return points[i].height + (points[i + 1].height - points[i].height) * ratio
            }
        }

        return last.height
    }

    var fishingScoreNow: (score: Int, reason: String) {
        fishingScore(seaTemp: nil)
    }

    func fishingScore(seaTemp: Double?) -> (score: Int, reason: String) {
        let hour = Calendar.current.component(.hour, from: Date())
        guard let info = tideInfo else { return (50, "") }
        return TideCalculator.fishingScore(for: info, at: hour, seaTemp: seaTemp)
    }

    var tideChartPoints: [TidePoint] {
        guard let info = tideInfo else { return [] }

        var jstCal = Calendar(identifier: .gregorian)
        jstCal.timeZone = TimeZone(identifier: "Asia/Tokyo")!

        let dateComponents = jstCal.dateComponents([.year, .month, .day], from: selectedDate)
        guard let dayStart = jstCal.date(from: dateComponents),
              let dayEnd = jstCal.date(byAdding: .day, value: 1, to: dayStart) else {
            return []
        }

        return info.points
            .filter { $0.type == nil && $0.time >= dayStart && $0.time < dayEnd }
            .sorted { $0.time < $1.time }
    }

    var tideExtrema: [TidePoint] {
        guard let info = tideInfo else { return [] }

        var jstCal = Calendar(identifier: .gregorian)
        jstCal.timeZone = TimeZone(identifier: "Asia/Tokyo")!

        let dateComponents = jstCal.dateComponents([.year, .month, .day], from: selectedDate)
        guard let dayStart = jstCal.date(from: dateComponents),
              let dayEnd = jstCal.date(byAdding: .day, value: 1, to: dayStart) else {
            return []
        }

        return info.points
            .filter { $0.type != nil && $0.time >= dayStart && $0.time < dayEnd }
            .sorted { $0.time < $1.time }
    }
}
