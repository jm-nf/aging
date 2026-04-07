import Foundation

// MARK: - Tackle Item Protocols

struct Rod: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var maker: String
    var name: String
    var lengthFt: Double        // e.g. 6.0 (フィート)
    var lureWeightRange: String // e.g. "0.5〜5g"
    var lineWeightRange: String // e.g. "PE 0.1〜0.4号"
    var tip: TipType = .solid
    var memo: String = ""

    var displayName: String { "\(maker) \(name)" }
    var lengthLabel: String { String(format: "%.1f ft", lengthFt) }

    enum TipType: String, Codable, CaseIterable {
        case solid   = "ソリッド"
        case tubular = "チューブラー"
        case titan   = "チタン"
    }
}

struct Reel: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var maker: String
    var name: String
    var size: String            // e.g. "500", "1000", "2000S"
    var gearRatio: String       // e.g. "5.1:1"
    var memo: String = ""

    var displayName: String { "\(maker) \(name) \(size)" }
}

struct FishingLine: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var maker: String
    var name: String
    var lineType: LineType
    var gauge: String           // e.g. "0.3号" / "0.6号"
    var strengthLb: Double = 0  // ポンド
    var lengthM: Int            // m
    var memo: String = ""

    var displayName: String { "\(maker) \(name) \(gauge)" }

    enum LineType: String, Codable, CaseIterable {
        case pe        = "PE"
        case fluoro    = "フロロカーボン"
        case nylon     = "ナイロン"
        case esteron   = "エステル"
    }
}

struct Leader: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var maker: String
    var name: String
    var gauge: String           // e.g. "0.8号" / "1号"
    var strengthLb: Double = 0  // ポンド
    var lengthM: Int            // m
    var memo: String = ""

    var displayName: String { "\(maker) \(name) \(gauge)" }
}

struct JigHead: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var maker: String
    var name: String
    var weight: Double          // g
    var hookSize: String        // e.g. "#6", "#8"
    var quantity: Int = 0       // 在庫数（0=未管理）
    var memo: String = ""

    var displayName: String { "\(maker) \(name) \(String(format: "%.1f", weight))g \(hookSize)" }
}

struct Worm: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var maker: String
    var name: String
    var lengthInch: Double      // e.g. 1.5
    var color: String
    var memo: String = ""

    var displayName: String { "\(maker) \(name) \(color)" }
    var lengthLabel: String { String(format: "%.1f\"", lengthInch) }
}

// MARK: - TackleSet (釣果記録との紐付け)

struct TackleSet: Codable {
    var rodId: UUID?
    var reelId: UUID?
    var lineId: UUID?
    var leaderId: UUID?
    var jigHeadId: UUID?
    var wormId: UUID?

    var isEmpty: Bool {
        rodId == nil && reelId == nil && lineId == nil &&
        leaderId == nil && jigHeadId == nil && wormId == nil
    }
}
