import Foundation

struct TidePoint: Identifiable {
    let id = UUID()
    let time: Date
    let height: Double // meters
    let type: TideType?

    enum TideType: String {
        case high = "満潮"
        case low = "干潮"
    }
}

struct TideInfo {
    let date: Date
    let location: TideLocation
    let points: [TidePoint]
    let moonPhase: Double // 0.0 - 1.0
    let moonPhaseName: String
    let moonAge: Double // days since new moon

    var todayHighTides: [TidePoint] {
        points.filter { $0.type == .high }
    }

    var todayLowTides: [TidePoint] {
        points.filter { $0.type == .low }
    }
}

enum TideLocation: String, CaseIterable {
    case yokohama = "横浜"
    case yokosuka = "横須賀"
    case kurihama = "久里浜"
    case misaki = "三崎"
    case shonan = "湘南"

    // 横浜基準の時刻オフセット（負=早い）
    var timeOffsetMinutes: Double {
        switch self {
        case .yokohama: return 0
        case .yokosuka: return -5
        case .kurihama: return -15
        case .misaki:   return -25
        case .shonan:   return -40  // 相模湾は東京湾より早い
        }
    }

    var heightMultiplier: Double {
        switch self {
        case .yokohama: return 1.00
        case .yokosuka: return 0.95
        case .kurihama: return 0.90
        case .misaki:   return 0.85
        case .shonan:   return 0.65  // 相模湾は潮差が小さい
        }
    }
}
