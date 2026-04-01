import Foundation

struct VesselInfo: Identifiable, Equatable, Codable {
    let id: UUID
    let vesselName: String       // 船名
    let callSign: String         // コールサイン
    let berth: String            // バース
    let arrivalDate: Date?       // 入港日時
    let departureDate: Date?     // 出港日時（予定）
    let nationality: String      // 国籍
    let grossTonnage: String     // 総トン数
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
        self.purpose = purpose
        self.status = status
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

    static func == (lhs: VesselInfo, rhs: VesselInfo) -> Bool {
        lhs.vesselName == rhs.vesselName &&
        lhs.arrivalDate == rhs.arrivalDate &&
        lhs.departureDate == rhs.departureDate &&
        lhs.berth == rhs.berth
    }
}
