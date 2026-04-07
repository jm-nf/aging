import Foundation

// MARK: - Vessel Size Category

enum VesselSizeCategory: String, Codable, CaseIterable {
    case small    = "小型"
    case medium   = "中型"
    case large    = "大型"
    case veryLarge = "超大型"
    case unknown  = "不明"

    var rangeLabel: String {
        switch self {
        case .small:     return "〜999 GT"
        case .medium:    return "1,000〜9,999 GT"
        case .large:     return "10,000〜49,999 GT"
        case .veryLarge: return "50,000 GT 以上"
        case .unknown:   return "GT 不明"
        }
    }

    var systemImage: String {
        switch self {
        case .small:     return "ferry"
        case .medium:    return "ferry.fill"
        case .large:     return "sailboat.fill"
        case .veryLarge: return "flag.fill"
        case .unknown:   return "questionmark.circle"
        }
    }
}

// MARK: - Schedule Event

struct ScheduleEvent: Identifiable {
    let id = UUID()
    let vessel: VesselInfo
    let eventType: EventType
    let date: Date

    enum EventType {
        case arrival
        case departure

        var label: String {
            switch self {
            case .arrival:   return "入港"
            case .departure: return "出港"
            }
        }

        var systemImage: String {
            switch self {
            case .arrival:   return "arrow.down.to.line"
            case .departure: return "arrow.up.to.line"
            }
        }
    }

    var isInFuture: Bool { date > Date() }
}

// MARK: - VesselInfo

struct VesselInfo: Identifiable, Equatable, Codable {
    let id: UUID
    let vesselName: String       // 船名
    let callSign: String         // コールサイン
    let berth: String            // バース
    let arrivalDate: Date?       // 入港日時
    let departureDate: Date?     // 出港日時（予定）
    let nationality: String      // 国籍
    let grossTonnage: String     // 総トン数
    let loa: String              // 全長 (m)
    let purpose: String          // 入港目的
    let status: String           // 状態

    init(
        id: UUID = UUID(),
        vesselName: String,
        callSign: String = "",
        berth: String,
        arrivalDate: Date? = nil,
        departureDate: Date? = nil,
        nationality: String = "",
        grossTonnage: String = "",
        loa: String = "",
        purpose: String = "",
        status: String = ""
    ) {
        self.id = id
        self.vesselName = vesselName
        self.callSign = callSign
        self.berth = berth
        self.arrivalDate = arrivalDate
        self.departureDate = departureDate
        self.nationality = nationality
        self.grossTonnage = grossTonnage
        self.loa = loa
        self.purpose = purpose
        self.status = status
    }

    // 全長メートル数（数値変換できない場合はnil）
    var loaMeters: Double? {
        let cleaned = loa.filter { $0.isNumber || $0 == "." }
        return Double(cleaned)
    }

    // 90m以上かどうか（全長データがない場合はトン数で推定）
    var isLargeVessel: Bool {
        if let meters = loaMeters {
            return meters >= 90
        }
        // フォールバック: 総トン数が概ね5,000GT以上なら90m相当とみなす
        let cleaned = grossTonnage.filter { $0.isNumber }
        if let tons = Int(cleaned) {
            return tons >= 5_000
        }
        return false
    }

    // 在泊中かどうか（現在時刻が入港〜出港予定の間にある）
    var isCurrentlyDocked: Bool {
        let now = Date()
        if let arrival = arrivalDate, let departure = departureDate {
            return now >= arrival && now <= departure
        }
        if let arrival = arrivalDate, departureDate == nil {
            return now >= arrival
        }
        return false
    }

    // 入港予定（まだ来ていない）
    var isUpcoming: Bool {
        guard let arrival = arrivalDate else { return false }
        return Date() < arrival
    }

    var dockingPeriodText: String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "ja_JP")
        fmt.dateFormat = "M/d HH:mm"
        let a = arrivalDate.map { fmt.string(from: $0) } ?? "不明"
        let d = departureDate.map { fmt.string(from: $0) } ?? "未定"
        return "\(a) 〜 \(d)"
    }

    var fishingImpactText: String {
        if isCurrentlyDocked { return "釣りに影響あり（在泊中）" }
        if isUpcoming { return "入港予定" }
        return "影響なし（出港済み）"
    }

    var fishingImpactColor: String {
        if isCurrentlyDocked { return "red" }
        if isUpcoming { return "orange" }
        return "green"
    }

    // 総トン数から船のサイズカテゴリを返す
    var sizeCategory: VesselSizeCategory {
        let cleaned = grossTonnage
            .filter { $0.isNumber }
        guard let tons = Int(cleaned), tons > 0 else { return .unknown }
        switch tons {
        case 0..<1_000:     return .small
        case 1_000..<10_000: return .medium
        case 10_000..<50_000: return .large
        default:            return .veryLarge
        }
    }

    // カンマ区切りでフォーマットした総トン数文字列
    var grossTonnageFormatted: String {
        let cleaned = grossTonnage.filter { $0.isNumber }
        guard let tons = Int(cleaned), tons > 0 else {
            return grossTonnage.isEmpty ? "GT不明" : grossTonnage
        }
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        return (fmt.string(from: NSNumber(value: tons)) ?? "\(tons)") + " GT"
    }

    static func == (lhs: VesselInfo, rhs: VesselInfo) -> Bool {
        lhs.vesselName == rhs.vesselName &&
        lhs.arrivalDate == rhs.arrivalDate &&
        lhs.departureDate == rhs.departureDate &&
        lhs.berth == rhs.berth
    }
}
