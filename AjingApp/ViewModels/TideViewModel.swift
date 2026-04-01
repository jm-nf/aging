import Foundation
import Combine

@MainActor
class TideViewModel: ObservableObject {
    @Published var tideInfo: TideInfo?
    @Published var selectedLocation: TideLocation = .yokohama
    @Published var selectedDate: Date = Date()

    init() {
        recalculate()
    }

    func recalculate() {
        tideInfo = TideCalculator.calculate(for: selectedDate, location: selectedLocation)
    }

    func updateLocation(_ location: TideLocation) {
        selectedLocation = location
        recalculate()
    }

    func updateDate(_ date: Date) {
        selectedDate = date
        recalculate()
    }

    var currentHeight: Double {
        TideCalculator.height(at: Date(), location: selectedLocation)
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
