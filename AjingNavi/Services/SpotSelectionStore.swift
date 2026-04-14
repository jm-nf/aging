import Foundation
import Combine

/// 選択中スポットを永続化するストア
/// FishingSpot.id は起動ごとに変わるため、spot.name をキーに保存する
@MainActor
final class SpotSelectionStore: ObservableObject {
    private static let key = "selected_spot_name_v1"

    @Published var selectedSpot: FishingSpot {
        didSet {
            UserDefaults.standard.set(selectedSpot.name, forKey: Self.key)
        }
    }

    init() {
        let saved = UserDefaults.standard.string(forKey: Self.key)
        if let saved,
           let spot = FishingSpot.yokohamaYokosuka.first(where: { $0.name == saved }) {
            self.selectedSpot = spot
        } else {
            self.selectedSpot = FishingSpot.yokohamaYokosuka[0]
        }
    }
}
