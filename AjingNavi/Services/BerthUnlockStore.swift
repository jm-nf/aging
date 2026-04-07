import Foundation
import Combine

class BerthUnlockStore: ObservableObject {
    @Published var isUnlocked: Bool {
        didSet { UserDefaults.standard.set(isUnlocked, forKey: "berthFeatureUnlocked") }
    }
    @Published var isAdminUnlocked: Bool {
        didSet { UserDefaults.standard.set(isAdminUnlocked, forKey: "berthAdminUnlocked") }
    }

    private let featureKeyword = "勝二郎"
    private let adminKeyword   = "nf-cosmo"

    init() {
        self.isUnlocked      = UserDefaults.standard.bool(forKey: "berthFeatureUnlocked")
        self.isAdminUnlocked = UserDefaults.standard.bool(forKey: "berthAdminUnlocked")
    }

    @discardableResult
    func tryUnlock(keyword: String) -> Bool {
        guard keyword == featureKeyword else { return false }
        isUnlocked = true
        return true
    }

    @discardableResult
    func tryAdminUnlock(keyword: String) -> Bool {
        guard keyword == adminKeyword else { return false }
        isAdminUnlocked = true
        return true
    }

    func lock() {
        isUnlocked = false
    }

    func adminLock() {
        isAdminUnlocked = false
    }
}
