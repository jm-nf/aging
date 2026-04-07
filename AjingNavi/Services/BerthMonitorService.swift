import Foundation
import Combine
import UserNotifications
import WebKit

// Yokohama Port vessel schedule scraper
// Monitors berth MTK0C for fishing impact
@MainActor
class BerthMonitorService: ObservableObject {

    @Published var vessels: [VesselInfo] = []
    @Published var isLoading = false
    @Published var lastUpdated: Date?
    @Published var errorMessage: String?
    @Published var notificationsEnabled = false

    private let targetBerth = "MTK0C"
    let berthDisplayName = "MTK0C 住友大阪セメント岸壁"
    private let cacheKey = "berth_mtk0c_vessels"
    private let lastUpdatedKey = "berth_mtk0c_last_updated"

    init() {
        loadFromCache()
        Task {
            await checkNotificationPermission()
        }
    }

    // MARK: - Fetch

    func fetch() async {
        isLoading = true
        errorMessage = nil

        do {
            let fetcher = BerthWebFetcher()
            let rows = try await fetcher.fetchArytbl()

            if rows.isEmpty {
                errorMessage = "データを取得できませんでした（arytbl空）"
                isLoading = false
                return
            }

            let previousVessels = vessels
            let parsed = rows.compactMap { parseVesselFromRow($0) }

            vessels = parsed
            lastUpdated = Date()
            saveToCache()

            if notificationsEnabled {
                await detectChangesAndNotify(previous: previousVessels, current: parsed)
            }
        } catch {
            errorMessage = "データ取得エラー: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - arytbl Row Parsing
    //
    // arytbl field indices (confirmed from page JS variable names):
    //  [0]=CallSign  [1]=VesselName  [2]=GT      [3]=LOA
    //  [4]=Status    [7]=Country     [8]=Route   [12]=PBerth(バース)
    //  [13]=PEta(入港予定)  [14]=PStart(スタート予定)
    //  [15]=PAta(着岸予定)  [16]=PAtd(離岸予定)
    //  [19]=EAta(着岸実績)  [21]=EAtd(離岸実績)
    //
    // NOTE: Fetch is done without berth filter (cbo_cberth=) because
    // specifying MTK0C in the URL causes the server to return arytbl=null.
    // Filtering is applied here by checking PBerth contains targetBerth.

    private func parseVesselFromRow(_ row: [String]) -> VesselInfo? {
        guard row.count >= 17 else { return nil }

        let callSign    = row[0]
        let vesselName  = row[1]
        let grossTon    = row[2]
        let loa         = row[3]
        let status      = row[4]
        let nationality = row.count > 7  ? row[7]  : ""
        let purpose     = row.count > 8  ? row[8]  : ""
        let berth       = row.count > 12 ? row[12] : ""

        guard !vesselName.isEmpty, vesselName != "null" else { return nil }

        // Client-side filter: only keep MTK0C berth rows
        guard berth.contains(targetBerth) else { return nil }

        // Prefer confirmed (実績) times; fall back to scheduled (予定)
        // [15]=PAta(着岸予定), [16]=PAtd(離岸予定)
        // [19]=EAta(着岸実績), [21]=EAtd(離岸実績)
        let confirmedArrival   = row.count > 19 ? row[19] : ""
        let confirmedDeparture = row.count > 21 ? row[21] : ""
        let scheduledArrival   = row.count > 15 ? row[15] : ""  // PAta
        let scheduledDeparture = row.count > 16 ? row[16] : ""  // PAtd

        let arrivalStr   = (confirmedArrival.isEmpty   || confirmedArrival   == "null") ? scheduledArrival   : confirmedArrival
        let departureStr = (confirmedDeparture.isEmpty || confirmedDeparture == "null") ? scheduledDeparture : confirmedDeparture

        return VesselInfo(
            vesselName: vesselName,
            callSign: callSign,
            berth: berth.trimmingCharacters(in: .whitespaces),
            arrivalDate: parseDate(arrivalStr),
            departureDate: parseDate(departureStr),
            nationality: nationality,
            grossTonnage: grossTon,
            loa: loa,
            purpose: purpose,
            status: status
        )
    }

    // MARK: - Date Parsing

    private func parseDate(_ str: String) -> Date? {
        let cleaned = str.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty && cleaned != "-" && cleaned != "　" else { return nil }

        let formats = [
            "yyyy/MM/dd HH:mm",
            "yyyy-MM-dd HH:mm",
            "yyyy/MM/dd",
            "yyyy年MM月dd日 HH時mm分",
            "yyyy年MM月dd日HH時mm分",
            "MM/dd HH:mm",
            "MM-dd HH:mm",
        ]

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")

        var jstCal = Calendar(identifier: .gregorian)
        jstCal.timeZone = TimeZone(identifier: "Asia/Tokyo")!

        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: cleaned) {
                // If year is missing, assume current year
                if format.hasPrefix("MM/") || format.hasPrefix("MM-") {
                    let year = jstCal.component(.year, from: Date())
                    var comps = jstCal.dateComponents([.month, .day, .hour, .minute], from: date)
                    comps.year = year
                    return jstCal.date(from: comps)
                }
                return date
            }
        }

        return nil
    }

    // MARK: - Notifications

    func requestNotificationPermission() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            notificationsEnabled = granted
        } catch {
            notificationsEnabled = false
        }
    }

    private func checkNotificationPermission() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationsEnabled = settings.authorizationStatus == .authorized
    }

    private func detectChangesAndNotify(previous: [VesselInfo], current: [VesselInfo]) async {
        let center = UNUserNotificationCenter.current()

        // New vessel arrived at MTK0C
        for vessel in current {
            let wasPresent = previous.contains { $0.vesselName == vessel.vesselName && $0.berth == vessel.berth }
            if !wasPresent && vessel.isCurrentlyDocked {
                let content = UNMutableNotificationContent()
                content.title = "⚓ MTK0Cバース 入港"
                content.body = "\(vessel.vesselName) が入港しました。\(vessel.dockingPeriodText)"
                content.sound = .default
                content.userInfo = ["berth": vessel.berth, "vessel": vessel.vesselName]

                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                let request = UNNotificationRequest(identifier: "arrival_\(vessel.vesselName)", content: content, trigger: trigger)
                try? await center.add(request)
            }
        }

        // Vessel departed (was in list before, not now)
        for vessel in previous where vessel.isCurrentlyDocked {
            let stillPresent = current.contains { $0.vesselName == vessel.vesselName && $0.berth == vessel.berth }
            if !stillPresent {
                let content = UNMutableNotificationContent()
                content.title = "🎣 MTK0Cバース 出港"
                content.body = "\(vessel.vesselName) が出港しました。釣りが再開できます！"
                content.sound = .default

                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                let request = UNNotificationRequest(identifier: "departure_\(vessel.vesselName)", content: content, trigger: trigger)
                try? await center.add(request)
            }
        }
    }

    // Schedule notification for upcoming vessel arrival
    func scheduleArrivalNotification(for vessel: VesselInfo) {
        guard let arrivalDate = vessel.arrivalDate else { return }
        let notifyDate = arrivalDate.addingTimeInterval(-3600) // 1 hour before
        guard notifyDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "⚓ MTK0Cバース 入港予告"
        content.body = "\(vessel.vesselName) が1時間後に入港予定です。"
        content.sound = .default

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: notifyDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: "upcoming_\(vessel.id)", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Cache

    private func saveToCache() {
        if let encoded = try? JSONEncoder().encode(vessels) {
            UserDefaults.standard.set(encoded, forKey: cacheKey)
        }
        if let lastUpdated {
            UserDefaults.standard.set(lastUpdated, forKey: lastUpdatedKey)
        }
    }

    private func loadFromCache() {
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let decoded = try? JSONDecoder().decode([VesselInfo].self, from: data) {
            vessels = decoded
        }
        lastUpdated = UserDefaults.standard.object(forKey: lastUpdatedKey) as? Date
    }

    // MARK: - Computed properties

    var currentlyDockedVessels: [VesselInfo] {
        vessels.filter { $0.isCurrentlyDocked }
    }

    var upcomingVessels: [VesselInfo] {
        vessels.filter { $0.isUpcoming }
            .sorted { ($0.arrivalDate ?? .distantFuture) < ($1.arrivalDate ?? .distantFuture) }
    }

    var isFishingAffected: Bool {
        !currentlyDockedVessels.isEmpty
    }

    var nextClearTime: Date? {
        currentlyDockedVessels
            .compactMap { $0.departureDate }
            .min()
    }

    // 将来の入出港イベントを時刻順に並べたリスト
    var scheduleEvents: [ScheduleEvent] {
        var events: [ScheduleEvent] = []
        for vessel in vessels {
            if let arrival = vessel.arrivalDate, arrival > Date() {
                events.append(ScheduleEvent(vessel: vessel, eventType: .arrival, date: arrival))
            }
            if let departure = vessel.departureDate, departure > Date() {
                events.append(ScheduleEvent(vessel: vessel, eventType: .departure, date: departure))
            }
        }
        return events.sorted { $0.date < $1.date }
    }
}
