import Foundation
import CoreLocation

struct FishingSpot: Identifiable, Equatable, Hashable {
    static func == (lhs: FishingSpot, rhs: FishingSpot) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    let id = UUID()
    let name: String
    let location: String            // 内部用（UI には表示しない）
    let coordinate: CLLocationCoordinate2D
    let description: String
    let bestSeason: String
    let bestTime: String
    let accessInfo: String
    let parkingAvailable: Bool
    let toiretAvailable: Bool
    let difficulty: Difficulty
    var isHidden: Bool = false

    enum Difficulty: String, CaseIterable {
        case beginner     = "初心者向け"
        case intermediate = "中級者向け"
        case advanced     = "上級者向け"

        var color: String {
            switch self {
            case .beginner:     return "green"
            case .intermediate: return "orange"
            case .advanced:     return "red"
            }
        }
    }

    /// 潮汐計算に使用するエリア（地理的に最も近い観測点）
    var tideLocation: TideLocation {
        switch name {
        case "久里浜":
            return .kurihama
        case "三崎":
            return .misaki
        case "江ノ島", "平塚", "大磯", "小田原":
            return .shonan
        case "うみかぜ公園", "海辺つり公園", "浦賀":
            return .yokosuka
        default: // 横浜湾岸全般
            return .yokohama
        }
    }
}

extension FishingSpot {
    static let yokohamaYokosuka: [FishingSpot] = [

        // ── 横浜エリア ──────────────────────────────

        FishingSpot(
            name: "聖地コスモ",
            location: "横浜市鶴見区大黒町7-97",
            coordinate: CLLocationCoordinate2D(latitude: 35.479, longitude: 139.670),
            description: "鶴見エリア。夜の常夜灯周りが狙い目。",
            bestSeason: "4月〜12月",
            bestTime: "夕マヅメ〜深夜",
            accessInfo: "新子安駅よりバス",
            parkingAvailable: true,
            toiretAvailable: true,
            difficulty: .intermediate,
            isHidden: true
        ),

        FishingSpot(
            name: "ベイブリッジ",
            location: "横浜市鶴見区大黒ふ頭",
            coordinate: CLLocationCoordinate2D(latitude: 35.4622, longitude: 139.6636),
            description: "大黒ふ頭エリア。潮通しが良く常夜灯周りでアジが回遊する。",
            bestSeason: "4月〜12月",
            bestTime: "夕マヅメ〜夜",
            accessInfo: "新子安駅よりバス",
            parkingAvailable: true,
            toiretAvailable: true,
            difficulty: .intermediate
        ),

        FishingSpot(
            name: "みなとみらい",
            location: "横浜市西区みなとみらい2",
            coordinate: CLLocationCoordinate2D(latitude: 35.4554, longitude: 139.6410),
            description: "横浜港の護岸エリア。夜間は常夜灯が多く豆アジ〜中アジが狙える。足場良好。",
            bestSeason: "5月〜11月",
            bestTime: "夜間",
            accessInfo: "みなとみらい駅より徒歩",
            parkingAvailable: true,
            toiretAvailable: true,
            difficulty: .beginner
        ),

        FishingSpot(
            name: "山下公園",
            location: "横浜市中区山下町279",
            coordinate: CLLocationCoordinate2D(latitude: 35.4441, longitude: 139.6522),
            description: "横浜港に面した公園護岸。常夜灯多く夜釣りに好適。港内ならではの穏やかな水面。",
            bestSeason: "4月〜11月",
            bestTime: "夜間",
            accessInfo: "元町・中華街駅より徒歩",
            parkingAvailable: true,
            toiretAvailable: true,
            difficulty: .beginner
        ),

        FishingSpot(
            name: "本牧",
            location: "横浜市中区本牧ふ頭",
            coordinate: CLLocationCoordinate2D(latitude: 35.4254, longitude: 139.6694),
            description: "本牧エリア。管理釣り場・護岸ともに実績あり。アジの回遊が安定している。",
            bestSeason: "4月〜11月",
            bestTime: "夕方〜深夜",
            accessInfo: "根岸駅よりバス",
            parkingAvailable: true,
            toiretAvailable: true,
            difficulty: .beginner
        ),

        FishingSpot(
            name: "根岸",
            location: "横浜市磯子区新磯子町",
            coordinate: CLLocationCoordinate2D(latitude: 35.4100, longitude: 139.6490),
            description: "根岸湾内の護岸エリア。湾奥で波が穏やかなため扱いやすい。小〜中アジが狙える。",
            bestSeason: "5月〜11月",
            bestTime: "夜間",
            accessInfo: "根岸駅より徒歩・バス",
            parkingAvailable: true,
            toiretAvailable: false,
            difficulty: .beginner
        ),

        FishingSpot(
            name: "磯子",
            location: "横浜市磯子区磯子",
            coordinate: CLLocationCoordinate2D(latitude: 35.3943, longitude: 139.6370),
            description: "磯子エリアの海釣り施設。常連が多い実績ポイント。夜の時間帯が特に釣果が安定。",
            bestSeason: "通年（夏〜秋が最盛期）",
            bestTime: "夜間",
            accessInfo: "新杉田駅よりバス",
            parkingAvailable: true,
            toiretAvailable: true,
            difficulty: .beginner
        ),

        FishingSpot(
            name: "八景島",
            location: "横浜市金沢区八景島",
            coordinate: CLLocationCoordinate2D(latitude: 35.3268, longitude: 139.6367),
            description: "八景島周辺の護岸・公園。常夜灯が多く夜のアジングに最適。足場が整備されている。",
            bestSeason: "4月〜12月",
            bestTime: "夕方〜夜",
            accessInfo: "海の公園南口駅より徒歩",
            parkingAvailable: true,
            toiretAvailable: true,
            difficulty: .beginner
        ),

        // ── 横須賀エリア ─────────────────────────────

        FishingSpot(
            name: "うみかぜ公園",
            location: "横須賀市新港町3-16",
            coordinate: CLLocationCoordinate2D(latitude: 35.2768, longitude: 139.6668),
            description: "横須賀港に面した大型公園。夜釣りが人気でアジングの好適地。常夜灯周りを狙う。",
            bestSeason: "4月〜12月",
            bestTime: "夜間〜朝マヅメ",
            accessInfo: "横須賀中央駅より徒歩",
            parkingAvailable: true,
            toiretAvailable: true,
            difficulty: .beginner
        ),

        FishingSpot(
            name: "海辺つり公園",
            location: "横須賀市安浦町1-1",
            coordinate: CLLocationCoordinate2D(latitude: 35.2820, longitude: 139.6530),
            description: "横須賀の無料海釣り公園。整備された護岸でファミリーにも人気。アジの回遊が安定。",
            bestSeason: "4月〜12月",
            bestTime: "夕マヅメ〜夜",
            accessInfo: "追浜駅より徒歩",
            parkingAvailable: true,
            toiretAvailable: true,
            difficulty: .beginner
        ),

        FishingSpot(
            name: "大津港",
            location: "横須賀市大津町2",
            coordinate: CLLocationCoordinate2D(latitude: 35.3087, longitude: 139.6579),
            description: "横須賀北部の港。小規模ながら常夜灯があり夜の豆アジ〜中アジが狙いやすい穴場。",
            bestSeason: "5月〜11月",
            bestTime: "夜間",
            accessInfo: "京急大津駅より徒歩",
            parkingAvailable: false,
            toiretAvailable: false,
            difficulty: .beginner
        ),

        FishingSpot(
            name: "浦賀",
            location: "横須賀市浦賀2-14",
            coordinate: CLLocationCoordinate2D(latitude: 35.2478, longitude: 139.7130),
            description: "浦賀湾の港エリア。東京湾奥から外洋へのルート上にあり良型アジの回遊期待大。",
            bestSeason: "5月〜11月",
            bestTime: "朝マヅメ・夕マヅメ",
            accessInfo: "浦賀駅より徒歩",
            parkingAvailable: true,
            toiretAvailable: false,
            difficulty: .intermediate
        ),

        FishingSpot(
            name: "久里浜",
            location: "横須賀市久里浜7-11",
            coordinate: CLLocationCoordinate2D(latitude: 35.2268, longitude: 139.7118),
            description: "フェリー発着港。港内・外堤防からアジングが楽しめる。夜間の常夜灯周りが狙い目。",
            bestSeason: "5月〜11月",
            bestTime: "夜間",
            accessInfo: "京急久里浜駅より徒歩",
            parkingAvailable: true,
            toiretAvailable: true,
            difficulty: .beginner
        ),

        // ── 三浦エリア ───────────────────────────────

        FishingSpot(
            name: "三崎",
            location: "三浦市三崎5-3",
            coordinate: CLLocationCoordinate2D(latitude: 35.1547, longitude: 139.6194),
            description: "三浦半島最南端の港。外洋の影響を受け大型アジの実績が高い。潮流の読みが重要。",
            bestSeason: "4月〜11月",
            bestTime: "夕マヅメ〜夜",
            accessInfo: "三崎口駅よりバス",
            parkingAvailable: true,
            toiretAvailable: true,
            difficulty: .intermediate
        ),

        // ── 湘南エリア ───────────────────────────────

        FishingSpot(
            name: "江ノ島",
            location: "藤沢市江の島1",
            coordinate: CLLocationCoordinate2D(latitude: 35.2993, longitude: 139.4799),
            description: "相模湾に浮かぶ島の港・護岸。外洋系の良型アジが期待できる。潮流が速い時間帯に注意。",
            bestSeason: "4月〜11月",
            bestTime: "朝マヅメ・夕マヅメ〜夜",
            accessInfo: "片瀬江ノ島駅より徒歩",
            parkingAvailable: true,
            toiretAvailable: true,
            difficulty: .intermediate
        ),

        FishingSpot(
            name: "平塚",
            location: "平塚市千石河岸",
            coordinate: CLLocationCoordinate2D(latitude: 35.3174, longitude: 139.3516),
            description: "平塚港・相模川河口エリア。河川の影響で栄養豊富。サイズは小ぶりだが数釣りが期待できる。",
            bestSeason: "5月〜10月",
            bestTime: "夕マヅメ〜夜",
            accessInfo: "平塚駅よりバス",
            parkingAvailable: true,
            toiretAvailable: true,
            difficulty: .beginner
        ),

        FishingSpot(
            name: "大磯",
            location: "中郡大磯町大磯",
            coordinate: CLLocationCoordinate2D(latitude: 35.3074, longitude: 139.3103),
            description: "大磯港・相模湾西部のポイント。足場の良い護岸からアジングが楽しめる。",
            bestSeason: "5月〜10月",
            bestTime: "夕方〜夜",
            accessInfo: "大磯駅より徒歩",
            parkingAvailable: true,
            toiretAvailable: true,
            difficulty: .beginner
        ),

        FishingSpot(
            name: "小田原",
            location: "小田原市早川1-10",
            coordinate: CLLocationCoordinate2D(latitude: 35.2516, longitude: 139.1513),
            description: "早川港・小田原港エリア。相模湾西端で外洋の影響が強く、良型回遊が期待できる。",
            bestSeason: "4月〜11月",
            bestTime: "朝マヅメ・夕マヅメ",
            accessInfo: "早川駅より徒歩",
            parkingAvailable: true,
            toiretAvailable: true,
            difficulty: .beginner
        ),
    ]
}
