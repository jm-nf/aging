import SwiftUI
import BackgroundTasks

@main
struct AjingApp: App {
    @StateObject private var berthService = BerthMonitorService()

    init() {
        registerBackgroundTasks()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(berthService)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    // フォアグラウンドに戻ったとき自動更新
                    Task { await berthService.fetch() }
                }
        }
    }

    // MARK: - Background Task

    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.ajingnavi.berth-refresh",
            using: nil
        ) { task in
            self.handleBerthRefresh(task: task as! BGAppRefreshTask)
        }
    }

    private func handleBerthRefresh(task: BGAppRefreshTask) {
        Self.scheduleNextBerthRefresh() // 次回をスケジュール

        let refreshTask = Task {
            await berthService.fetch()
            task.setTaskCompleted(success: true)
        }

        task.expirationHandler = {
            refreshTask.cancel()
            task.setTaskCompleted(success: false)
        }
    }

    static func scheduleNextBerthRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "com.ajingnavi.berth-refresh")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60) // 30分後
        try? BGTaskScheduler.shared.submit(request)
    }
}
