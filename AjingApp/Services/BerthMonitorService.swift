import Foundation
import UserNotifications

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
    private let cacheKey = "berth_mtk0c_vessels"
    private let lastUpdatedKey = "berth_mtk0c_last_updated"

    // 横浜港 入港予定照会
    private var fetchURL: URL? {
        var components = URLComponents(string: "https://www.port.city.yokohama.lg.jp/APP/Pves0040InPlanC")
        components?.queryItems = [
            URLQueryItem(name: "hid_sessionid", value: ""),
            URLQueryItem(name: "hid_gamenid", value: "Jyoho04"),
            URLQueryItem(name: "hid_userid", value: ""),
            URLQueryItem(name: "cbo_cberth", value: targetBerth),
            URLQueryItem(name: "txt_cetay", value: ""),
            URLQueryItem(name: "txt_cetam", value: ""),
            URLQueryItem(name: "txt_cetad", value: ""),
            URLQueryItem(name: "cbo_status", value: ""),
            URLQueryItem(name: "txt_callsign", value: ""),
        ]
        return components?.url
    }

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

        guard let url = fetchURL else {
            errorMessage = "URLの生成に失敗しました"
            isLoading = false
            return
        }

        do {
            var request = URLRequest(url: url)
            request.setValue(
                "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
                forHTTPHeaderField: "User-Agent"
            )
            request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
            request.setValue("ja,en-US;q=0.9,en;q=0.8", forHTTPHeaderField: "Accept-Language")
            request.timeoutInterval = 30

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }

            guard httpResponse.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }

            // Try UTF-8 first, then Shift-JIS (common for Japanese government sites)
            let html: String
            if let utf8 = String(data: data, encoding: .utf8) {
                html = utf8
            } else if let sjis = String(data: data, encoding: .shiftJIS) {
                html = sjis
            } else if let isoJP = String(data: data, encoding: .japaneseEUC) {
                html = isoJP
            } else {
                throw NSError(domain: "BerthMonitor", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "文字コードの解析に失敗しました"])
            }

            let previousVessels = vessels
            let parsed = parseVesselsFromHTML(html)

            vessels = parsed
            lastUpdated = Date()
            saveToCache()

            // Send notifications if vessel status changed
            if notificationsEnabled {
                await detectChangesAndNotify(previous: previousVessels, current: parsed)
            }

        } catch {
            errorMessage = "データの取得に失敗しました: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - HTML Parsing

    private func parseVesselsFromHTML(_ html: String) -> [VesselInfo] {
        var results: [VesselInfo] = []

        // The Yokohama port site returns an HTML table with vessel data.
        // Parse <tr> rows from the results table.
        // Typical columns: 船名, コールサイン, 入港バース, 入港日時, 出港予定日時, 国籍, 総トン数, 目的, 状況

        // Find the main data table
        guard let tableRange = findMainTable(in: html) else {
            // If we can't find a table, try parsing any tabular data
            return parseFromAnyTable(html)
        }

        let tableHTML = String(html[tableRange])
        let rows = extractRows(from: tableHTML)

        // Skip header row(s)
        for row in rows.dropFirst() {
            let cells = extractCells(from: row)
            if cells.count >= 5 {
                if let vessel = parseVesselFromCells(cells) {
                    results.append(vessel)
                }
            }
        }

        return results
    }

    private func findMainTable(in html: String) -> Range<String.Index>? {
        // Look for a table that contains vessel data
        // The page likely has a results table after the search form
        var searchStart = html.startIndex
        var lastTableRange: Range<String.Index>?

        while let tableStart = html.range(of: "<table", options: .caseInsensitive, range: searchStart..<html.endIndex) {
            if let tableEnd = html.range(of: "</table>", options: .caseInsensitive, range: tableStart.upperBound..<html.endIndex) {
                let candidate = tableStart.lowerBound..<tableEnd.upperBound
                let content = String(html[candidate])
                // Prefer tables that contain vessel-related keywords
                if content.contains("船名") || content.contains("バース") ||
                   content.contains("入港") || content.contains("callsign") ||
                   content.contains(targetBerth) {
                    lastTableRange = candidate
                }
                searchStart = tableEnd.upperBound
            } else {
                break
            }
        }

        return lastTableRange
    }

    private func parseFromAnyTable(_ html: String) -> [VesselInfo] {
        // Fallback: try to extract any structured data from the page
        var results: [VesselInfo] = []

        // Look for berth MTK0C mentions and extract surrounding context
        var searchRange = html.startIndex..<html.endIndex
        while let berthRange = html.range(of: targetBerth, range: searchRange) {
            // Find the surrounding row context
            let contextStart = html.index(berthRange.lowerBound, offsetBy: -500, limitedBy: html.startIndex) ?? html.startIndex
            let contextEnd = html.index(berthRange.upperBound, offsetBy: 500, limitedBy: html.endIndex) ?? html.endIndex
            let context = String(html[contextStart..<contextEnd])

            // Try to extract vessel name from surrounding text
            let cleanText = stripTags(context)
            let lines = cleanText.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

            if !lines.isEmpty {
                results.append(VesselInfo(
                    vesselName: lines.first ?? "不明",
                    berth: targetBerth,
                    status: "在泊中"
                ))
            }

            searchRange = berthRange.upperBound..<html.endIndex
        }

        return results
    }

    private func extractRows(from tableHTML: String) -> [String] {
        var rows: [String] = []
        var searchRange = tableHTML.startIndex..<tableHTML.endIndex

        while let trStart = tableHTML.range(of: "<tr", options: .caseInsensitive, range: searchRange),
              let trEnd = tableHTML.range(of: "</tr>", options: .caseInsensitive, range: trStart.upperBound..<tableHTML.endIndex) {
            rows.append(String(tableHTML[trStart.lowerBound..<trEnd.upperBound]))
            searchRange = trEnd.upperBound..<tableHTML.endIndex
        }

        return rows
    }

    private func extractCells(from rowHTML: String) -> [String] {
        var cells: [String] = []
        var searchRange = rowHTML.startIndex..<rowHTML.endIndex

        // Match both <td> and <th>
        let tags = ["<td", "<th"]

        while true {
            var earliestStart: Range<String.Index>? = nil
            var matchedTag = ""

            for tag in tags {
                if let r = rowHTML.range(of: tag, options: .caseInsensitive, range: searchRange) {
                    if earliestStart == nil || r.lowerBound < earliestStart!.lowerBound {
                        earliestStart = r
                        matchedTag = tag == "<td" ? "</td>" : "</th>"
                    }
                }
            }

            guard let cellStart = earliestStart else { break }

            if let cellEnd = rowHTML.range(of: matchedTag, options: .caseInsensitive, range: cellStart.upperBound..<rowHTML.endIndex) {
                let cellContent = String(rowHTML[cellStart.lowerBound..<cellEnd.upperBound])
                cells.append(stripTags(cellContent).trimmingCharacters(in: .whitespacesAndNewlines))
                searchRange = cellEnd.upperBound..<rowHTML.endIndex
            } else {
                break
            }
        }

        return cells
    }

    private func parseVesselFromCells(_ cells: [String]) -> VesselInfo? {
        // Column mapping based on typical Yokohama port table structure:
        // 0: 行番号, 1: 船名, 2: コールサイン, 3: バース, 4: 入港日時, 5: 出港予定, 6: 国籍, 7: 総トン数, 8: 目的, 9: 状況
        // The exact column order may vary. We use heuristics.

        guard cells.count >= 3 else { return nil }

        // Skip header rows
        let firstCell = cells[0].lowercased()
        if firstCell.contains("船名") || firstCell.contains("バース") || firstCell == "no" || firstCell == "番号" {
            return nil
        }

        // Find berth column - must contain MTK0C or be empty (when filtered)
        let berthCell = cells.first { $0.contains(targetBerth) } ?? ""
        if berthCell.isEmpty && !cells.joined().contains(targetBerth) {
            // This row doesn't seem to be for our berth when not filtered
        }

        // Best-effort mapping
        let vesselName = cells.count > 1 ? cells[1] : cells[0]
        let callSign   = cells.count > 2 ? cells[2] : ""
        let berth      = berthCell.isEmpty ? targetBerth : berthCell
        let arrivalStr = cells.count > 4 ? cells[4] : (cells.count > 3 ? cells[3] : "")
        let deptStr    = cells.count > 5 ? cells[5] : ""
        let nationality = cells.count > 6 ? cells[6] : ""
        let grossTon   = cells.count > 7 ? cells[7] : ""
        let purpose    = cells.count > 8 ? cells[8] : ""
        let status     = cells.count > 9 ? cells[9] : ""

        guard !vesselName.isEmpty && vesselName != "-" else { return nil }

        return VesselInfo(
            vesselName: vesselName,
            callSign: callSign,
            berth: berth,
            arrivalDate: parseDate(arrivalStr),
            departureDate: parseDate(deptStr),
            nationality: nationality,
            grossTonnage: grossTon,
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

        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: cleaned) {
                // If year is missing, assume current year
                if format.hasPrefix("MM/") || format.hasPrefix("MM-") {
                    let cal = Calendar.current
                    let year = cal.component(.year, from: Date())
                    var comps = cal.dateComponents([.month, .day, .hour, .minute], from: date)
                    comps.year = year
                    return cal.date(from: comps)
                }
                return date
            }
        }

        return nil
    }

    // MARK: - HTML Tag Stripping

    private func stripTags(_ html: String) -> String {
        var result = html
        // Remove HTML tags
        while let start = result.range(of: "<"), let end = result.range(of: ">", range: start.upperBound..<result.endIndex) {
            result.replaceSubrange(start.lowerBound..<end.upperBound, with: " ")
        }
        // Decode common HTML entities
        result = result
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#160;", with: " ")
        // Collapse whitespace
        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
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
}
