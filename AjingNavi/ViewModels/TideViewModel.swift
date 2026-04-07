import Foundation
import Combine

@MainActor
class TideViewModel: ObservableObject {
    @Published var tideInfo: TideInfo?
    @Published var selectedSpot: FishingSpot = FishingSpot.yokohamaYokosuka[0]
    @Published var selectedDate: Date = Date()

    init(spot: FishingSpot = FishingSpot.yokohamaYokosuka[0]) {
        self.selectedSpot = spot
        recalculate()
    }

    func recalculate() {
        tideInfo = TideCalculator.calculate(for: selectedDate, location: selectedSpot.tideLocation)
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
        TideCalculator.height(at: Date(), location: selectedSpot.tideLocation)
    }

    var fishingScoreNow: (score: Int, reason: String) {
        let hour = Calendar.current.component(.hour, from: Date())
        guard let info = tideInfo else { return (50, "") }
        return TideCalculator.fishingScore(for: info, at: hour)
    }

    var tideChartPoints: [TidePoint] {
        tideInfo?.points.filter { $0.type == nil }.sorted { $0.time < $1.time } ?? []
    }

    var tideExtrema: [TidePoint] {
        tideInfo?.points.filter { $0.type != nil }.sorted { $0.time < $1.time } ?? []
    }
}
