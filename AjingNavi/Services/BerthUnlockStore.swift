import Foundation
import Combine

class BerthUnlockStore: ObservableObject {
    @Published var isUnlocked: Bool {
        didSet { UserDefaults.standard.set(isUnlocked, forKey: "berthFeatureUnlocked") }
    }

    private let featureKeyword = "勝二郎"

    init() {
        // 旧管理者ロック状態も統合（どちらかが解除済みなら解除扱い）
        let wasUnlocked = UserDefaults.standard.bool(forKey: "berthFeatureUnlocked")
        let wasAdminUnlocked = UserDefaults.standard.bool(forKey: "berthAdminUnlocked")
        self.isUnlocked = wasUnlocked || wasAdminUnlocked
    }

    @discardableResult
    func tryUnlock(keyword: String) -> Bool {
        guard keyword == featureKeyword else { return false }
        isUnlocked = true
        return true
    }

    func lock() {
        isUnlocked = false
        UserDefaults.standard.set(false, forKey: "berthAdminUnlocked")
    }
}
