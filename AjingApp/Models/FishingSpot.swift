import Foundation
import CoreLocation

struct FishingSpot: Identifiable {
    let id = UUID()
    let name: String
    let location: String
    let coordinate: CLLocationCoordinate2D
    let description: String
    let bestSeason: String
    let bestTime: String
    let accessInfo: String
    let parkingAvailable: Bool
    let toiretAvailable: Bool
    let difficulty: Difficulty

    enum Difficulty: String, CaseIterable {
        case beginner = "初心者向け"
        case intermediate = "中級者向け"
        case advanced = "上級者向け"

        var color: String {
            switch self {
            case .beginner: return "green"
            case .intermediate: return "orange"
            case .advanced: return "red"
            }
        }
    }
}

extension FishingSpot {
    static let yokohamaYokosuka: [FishingSpot] = [
        FishingSpot(
            name: "本牧海釣り施設",
            location: "横浜市中区",
            coordinate: CLLocationCoordinate2D(latitude: 35.4328, longitude: 139.6618),
            description: "横浜を代表する海釣り施設。管理釣り場で初心者も安心。アジングは夕マヅメ〜夜が狙い目。",
            bestSeason: "4月〜11月",
            bestTime: "夕方〜深夜",
            accessInfo: "根岸駅よりバス15分",
            parkingAvailable: true,
            toiretAvailable: true,
            difficulty: .beginner
        ),
        FishingSpot(
            name: "大黒海釣り公園",
            location: "横浜市鶴見区",
            coordinate: CLLocationCoordinate2D(latitude: 35.4702, longitude: 139.6614),
            description: "大黒ふ頭に隣接する公園。回遊してくるアジを狙う。潮通しが良く魚影が濃い。",
            bestSeason: "5月〜12月",
            bestTime: "夕マヅメ〜夜",
            accessInfo: "新子安駅よりバス20分、駐車場あり",
            parkingAvailable: true,
            toiretAvailable: true,
            difficulty: .beginner
        ),
        FishingSpot(
            name: "磯子海釣り公園",
            location: "横浜市磯子区",
            coordinate: CLLocationCoordinate2D(latitude: 35.3943, longitude: 139.6370),
            description: "磯子の老舗海釣り施設。アジの魚影が濃く、常連客も多い。夜釣りは特に実績あり。",
            bestSeason: "通年（夏〜秋が最盛期）",
            bestTime: "夜間",
            accessInfo: "新杉田駅よりバス10分",
            parkingAvailable: true,
            toiretAvailable: true,
            difficulty: .beginner
        ),
        FishingSpot(
            name: "横須賀うみかぜ公園",
            location: "横須賀市新港町",
            coordinate: CLLocationCoordinate2D(latitude: 35.2768, longitude: 139.6668),
            description: "横須賀港に面した大型公園。夜釣りが人気でアジング好適地。常夜灯周りが狙い目。",
            bestSeason: "4月〜12月",
            bestTime: "夜間〜朝マヅメ",
            accessInfo: "横須賀中央駅より徒歩15分",
            parkingAvailable: true,
            toiretAvailable: true,
            difficulty: .beginner
        ),
        FishingSpot(
            name: "走水漁港",
            location: "横須賀市走水",
            coordinate: CLLocationCoordinate2D(latitude: 35.2703, longitude: 139.7264),
            description: "東京湾の出口に位置する好漁場。大型アジの実績が高い穴場スポット。",
            bestSeason: "5月〜11月",
            bestTime: "朝マヅメ・夕マヅメ",
            accessInfo: "馬堀海岸駅よりバス15分",
            parkingAvailable: true,
            toiretAvailable: false,
            difficulty: .intermediate
        ),
        FishingSpot(
            name: "観音崎",
            location: "横須賀市鴨居",
            coordinate: CLLocationCoordinate2D(latitude: 35.2926, longitude: 139.7538),
            description: "東京湾口の岬。磯場からのアジングで良型が期待できる。潮流が速いため中級者以上推奨。",
            bestSeason: "5月〜10月",
            bestTime: "潮の動く時間帯",
            accessInfo: "浦賀駅よりバス20分",
            parkingAvailable: true,
            toiretAvailable: true,
            difficulty: .intermediate
        ),
        FishingSpot(
            name: "城ヶ島",
            location: "三浦市三崎町",
            coordinate: CLLocationCoordinate2D(latitude: 35.1380, longitude: 139.6164),
            description: "神奈川最南端の島。外洋に面しており大型アジが釣れる。磯場メインで上級者向け。",
            bestSeason: "4月〜11月",
            bestTime: "夕マヅメ〜夜",
            accessInfo: "三崎口駅よりバス30分",
            parkingAvailable: true,
            toiretAvailable: true,
            difficulty: .advanced
        ),
        FishingSpot(
            name: "野島公園",
            location: "横浜市金沢区",
            coordinate: CLLocationCoordinate2D(latitude: 35.3293, longitude: 139.6258),
            description: "八景島の近くにある公園。常夜灯が多く夜のアジングに最適。足場も良い。",
            bestSeason: "4月〜12月",
            bestTime: "夜間",
            accessInfo: "海の公園南口駅より徒歩5分",
            parkingAvailable: true,
            toiretAvailable: true,
            difficulty: .beginner
        ),
        FishingSpot(
            name: "八景島周辺",
            location: "横浜市金沢区",
            coordinate: CLLocationCoordinate2D(latitude: 35.3268, longitude: 139.6367),
            description: "八景島シーパラダイス周辺の護岸。常夜灯あり夜釣り好適。ファミリーにも人気。",
            bestSeason: "4月〜11月",
            bestTime: "夕方〜夜",
            accessInfo: "海の公園南口駅より徒歩10分",
            parkingAvailable: true,
            toiretAvailable: true,
            difficulty: .beginner
        ),
        FishingSpot(
            name: "久里浜港",
            location: "横須賀市久里浜",
            coordinate: CLLocationCoordinate2D(latitude: 35.2268, longitude: 139.7118),
            description: "フェリーが発着する港。港内・外堤防からアジングが楽しめる。夜間は常夜灯周りを狙う。",
            bestSeason: "5月〜11月",
            bestTime: "夜間",
            accessInfo: "京急久里浜駅より徒歩15分",
            parkingAvailable: true,
            toiretAvailable: true,
            difficulty: .beginner
        ),
    ]
}
