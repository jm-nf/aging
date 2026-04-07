import Foundation
import Combine

// MARK: - Settings Model

struct ShareSettings: Codable {
    // ヘッダー
    var headerText: String = "🎣 アジング釣果"

    // 本文項目
    var includeSpot: Bool = true
    var includeDate: Bool = true
    var includeTime: Bool = true        // 時刻・釣行時間
    var includeFishCount: Bool = true
    var includeMaxSize: Bool = true
    var includeWeather: Bool = true
    var includeTide: Bool = true
    var includeMemo: Bool = false

    // タックルセクション全体
    var includeTackle: Bool = true
    // タックル各項目
    var tackleRod: Bool = true
    var tackleReel: Bool = true
    var tackleLine: Bool = true
    var tackleLeader: Bool = true
    var tackleJigHead: Bool = true
    var tackleWorm: Bool = true

    // ハッシュタグ（改行区切り）
    var hashtags: String = "#アジング\n#アジ\n#釣果"

    // カスタムフッター（任意）
    var customFooter: String = ""

    // ハッシュタグを1行テキストにして返す
    var hashtagLine: String {
        hashtags
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

// MARK: - Store

@MainActor
class ShareSettingsStore: ObservableObject {
    @Published var settings = ShareSettings() {
        didSet { save() }
    }

    private let key = "shareSettings_v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode(ShareSettings.self, from: data) {
            settings = decoded
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func reset() {
        settings = ShareSettings()
    }
}
