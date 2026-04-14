import SwiftUI

struct BerthMonitorView: View {
    @EnvironmentObject var service: BerthMonitorService
    @EnvironmentObject var vesselProfileStore: VesselProfileStore
    @EnvironmentObject var berthUnlockStore: BerthUnlockStore
    @State private var showNotificationAlert = false
    @State private var showHistory = false
    @State private var showDatabase = false
    @State private var selectedVessel: VesselInfo? = nil
    @State private var autoRefreshTimer: Timer?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    statusBanner
                    controlBar
                    if service.isLoading {
                        loadingView
                    } else if service.vessels.isEmpty {
                        emptyState
                    } else {
                        berthGanttCard
                    }
                    if let error = service.errorMessage {
                        errorView(error)
                    }
                    dataSourceNote
                }
                .padding()
            }
            .navigationTitle("住友大阪セメント岸壁")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showHistory = true
                        } label: {
                            Label("入船履歴", systemImage: "clock.arrow.counterclockwise")
                        }
                        Button {
                            showDatabase = true
                        } label: {
                            Label("船舶データベース", systemImage: "list.bullet.rectangle")
                        }
                        Divider()
                        Button {
                            Task { await service.fetch() }
                        } label: {
                            Label("今すぐ更新", systemImage: "arrow.clockwise")
                        }
                        Button {
                            Task { await service.requestNotificationPermission() }
                        } label: {
                            Label(
                                service.notificationsEnabled ? "通知ON（タップで設定へ）" : "通知を有効にする",
                                systemImage: service.notificationsEnabled ? "bell.fill" : "bell.slash"
                            )
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .navigationDestination(isPresented: $showHistory) {
                VesselHistoryView()
                    .environmentObject(vesselProfileStore)
                    .environmentObject(service)
                    .environmentObject(berthUnlockStore)
            }
            .navigationDestination(isPresented: $showDatabase) {
                VesselDatabaseView()
                    .environmentObject(vesselProfileStore)
                    .environmentObject(service)
                    .environmentObject(berthUnlockStore)
            }
            .sheet(item: $selectedVessel) { v in
                NavigationStack {
                    VesselProfileView(vesselName: v.vesselName, vessel: v)
                        .environmentObject(vesselProfileStore)
                        .environmentObject(berthUnlockStore)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("閉じる") { selectedVessel = nil }
                            }
                        }
                }
            }
            .refreshable {
                await service.fetch()
            }
            .onAppear {
                if service.vessels.isEmpty {
                    Task {
                        await service.fetch()
                        vesselProfileStore.upsertFromFetch(service.vessels)
                    }
                } else {
                    vesselProfileStore.upsertFromFetch(service.vessels)
                }
                startAutoRefresh()
            }
            .onDisappear {
                stopAutoRefresh()
            }
        }
    }

    // MARK: - Status Banner

    private var statusBanner: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: service.isFishingAffected ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(service.isFishingAffected ? .red : .green)

                VStack(alignment: .leading, spacing: 2) {
                    Text(service.isFishingAffected ? "釣りに影響あり" : "釣り可能")
                        .font(.title3.bold())
                        .foregroundStyle(service.isFishingAffected ? .red : .green)

                    if service.isFishingAffected {
                        if let docked = service.currentlyDockedVessels.first {
                            Text(docked.vesselName)
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                        } else {
                            Text("住友大阪セメント岸壁に船が停泊中")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else if !service.upcomingVessels.isEmpty {
                        let next = service.upcomingVessels[0]
                        if let arrival = next.arrivalDate {
                            Text("次の入港: \(arrival, style: .relative)後")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    } else {
                        Text("住友大阪セメント岸壁は空き状態")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Fishing impact icon
                Text(service.isFishingAffected ? "🚫" : "🎣")
                    .font(.system(size: 40))
            }

            if service.isFishingAffected, let clearTime = service.nextClearTime {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundStyle(.orange)
                    Text("出港予定: \(clearTime, style: .relative)後 (\(clearTime.formatted(date: .omitted, time: .shortened)))")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                    Spacer()
                }
                // 次の入港予定船があれば表示
                if let nextUp = service.upcomingVessels.first {
                    nextVesselRow(vessel: nextUp)
                }
            } else if !service.upcomingVessels.isEmpty {
                let next = service.upcomingVessels[0]
                nextVesselRow(vessel: next)
            }
        }
        .padding()
        .background(service.isFishingAffected ? Color.red.opacity(0.08) : Color.green.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(service.isFishingAffected ? Color.red.opacity(0.3) : Color.green.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Next Vessel Row

    @ViewBuilder
    private func nextVesselRow(vessel: VesselInfo) -> some View {
        let timeFmt: DateFormatter = {
            let f = DateFormatter()
            f.locale = Locale(identifier: "ja_JP")
            f.timeZone = TimeZone(identifier: "Asia/Tokyo")
            f.dateFormat = "M/d(E) HH:mm"
            return f
        }()

        HStack(spacing: 6) {
            Image(systemName: "ferry.fill")
                .font(.caption)
                .foregroundStyle(.blue)
            Text(vessel.vesselName)
                .font(.caption.bold())
                .foregroundStyle(.primary)
                .lineLimit(1)
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 1) {
                if let arr = vessel.arrivalDate {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.down.to.line")
                            .font(.system(size: 9))
                            .foregroundStyle(.orange)
                        Text(timeFmt.string(from: arr))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.orange)
                    }
                }
                if let dep = vessel.departureDate {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.up.to.line")
                            .font(.system(size: 9))
                            .foregroundStyle(.blue)
                        Text(timeFmt.string(from: dep))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.blue)
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.blue.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Control Bar

    private var controlBar: some View {
        HStack {
            if let updated = service.lastUpdated {
                VStack(alignment: .leading, spacing: 2) {
                    Text("最終更新")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(updated, style: .relative)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                if service.notificationsEnabled {
                    Label("通知ON", systemImage: "bell.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Capsule())
                }

                Button {
                    Task { await service.fetch() }
                } label: {
                    Label("更新", systemImage: "arrow.clockwise")
                        .font(.subheadline.bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                .disabled(service.isLoading)
            }
        }
    }

    // MARK: - Gantt Chart Card

    private var berthGanttCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("在泊スケジュール（前後10日）", systemImage: "calendar.badge.clock")
                .font(.headline)

            BerthGanttChart(vessels: service.vessels, onLongPressVessel: { vessel in
                selectedVessel = vessel
            })
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8)
    }

    // MARK: - Empty / Loading / Error

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.5)
            Text("横浜港の情報を取得中...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "anchor")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("住友大阪セメント岸壁に予定船舶なし")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("取得済みの期間内に在泊予定の船はありません")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }

    private func errorView(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.red)
            Text(message)
                .font(.caption)
                .foregroundStyle(.red)
        }
        .padding()
        .background(Color.red.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var dataSourceNote: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                Text("データソース")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
            Text("横浜市港湾局 入港予定情報システムより取得。情報は公式サイトと若干異なる場合があります。")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Auto Refresh (30分間隔)

    private func startAutoRefresh() {
        autoRefreshTimer = Timer.scheduledTimer(withTimeInterval: 30 * 60, repeats: true) { _ in
            Task {
                await service.fetch()
            }
        }
    }

    private func stopAutoRefresh() {
        autoRefreshTimer?.invalidate()
        autoRefreshTimer = nil
    }
}

// MARK: - Vessel Card

struct VesselCard: View {
    let vessel: VesselInfo
    var onScheduleNotification: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(vessel.vesselName)
                        .font(.headline)
                    if !vessel.callSign.isEmpty {
                        Text("コールサイン: \(vessel.callSign)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                statusBadge
            }

            Divider()

            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("入港", systemImage: "arrow.down.to.line")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if let arrival = vessel.arrivalDate {
                        Text(arrival, style: .date)
                            .font(.caption.bold())
                        Text(arrival, style: .time)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("不明").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 4) {
                    Label("出港予定", systemImage: "arrow.up.to.line")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if let departure = vessel.departureDate {
                        Text(departure, style: .date)
                            .font(.caption.bold())
                        Text(departure, style: .time)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("未定").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 8) {
                VesselSizeBadge(vessel: vessel)
                if !vessel.nationality.isEmpty {
                    Label(vessel.nationality, systemImage: "flag.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if !vessel.purpose.isEmpty {
                    Label(vessel.purpose, systemImage: "doc.text")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // Schedule notification button for upcoming vessels
            if let notify = onScheduleNotification, vessel.isUpcoming, vessel.arrivalDate != nil {
                Button {
                    notify()
                } label: {
                    Label("入港1時間前に通知", systemImage: "bell.badge")
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.1))
                        .foregroundStyle(.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.06), radius: 6)
    }

    private var statusBadge: some View {
        Group {
            if vessel.isCurrentlyDocked {
                Label("停泊中", systemImage: "anchor")
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.12))
                    .foregroundStyle(.red)
                    .clipShape(Capsule())
            } else if vessel.isUpcoming {
                Label("入港予定", systemImage: "clock")
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.12))
                    .foregroundStyle(.orange)
                    .clipShape(Capsule())
            } else {
                Label("出港済", systemImage: "checkmark.circle")
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.12))
                    .foregroundStyle(.green)
                    .clipShape(Capsule())
            }
        }
    }
}

// MARK: - Vessel Size Badge

struct VesselSizeBadge: View {
    let vessel: VesselInfo

    private var color: Color {
        switch vessel.sizeCategory {
        case .small:     return .green
        case .medium:    return .yellow
        case .large:     return .orange
        case .veryLarge: return .red
        case .unknown:   return .secondary
        }
    }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "scalemass.fill")
            Text(vessel.sizeCategory.rawValue)
            Text("·")
            Text(vessel.grossTonnageFormatted)
        }
        .font(.caption2.bold())
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(color.opacity(0.15))
        .foregroundStyle(color)
        .clipShape(Capsule())
    }
}

// MARK: - Day Schedule Card

struct DayScheduleCard: View {
    let day: Date
    let events: [ScheduleEvent]
    let onScheduleNotification: (VesselInfo) -> Void

    private var dayLabel: String {
        if Calendar.current.isDateInToday(day) { return "今日" }
        if Calendar.current.isDateInTomorrow(day) { return "明日" }
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "ja_JP")
        fmt.dateFormat = "M月d日(E)"
        return fmt.string(from: day)
    }

    private var dateSubLabel: String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "ja_JP")
        fmt.dateFormat = "M/d"
        return fmt.string(from: day)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Day header
            HStack {
                Text(dayLabel)
                    .font(.subheadline.bold())
                if !Calendar.current.isDateInToday(day) && !Calendar.current.isDateInTomorrow(day) {
                    Text(dateSubLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(events.count)件")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.secondarySystemGroupedBackground))

            ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                ScheduleEventRow(event: event, onScheduleNotification: onScheduleNotification)
                if index < events.count - 1 {
                    Divider().padding(.leading, 60)
                }
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.06), radius: 6)
    }
}

// MARK: - Schedule Event Row

struct ScheduleEventRow: View {
    let event: ScheduleEvent
    let onScheduleNotification: (VesselInfo) -> Void

    private var eventColor: Color {
        event.eventType == .arrival ? .orange : .blue
    }

    var body: some View {
        HStack(spacing: 10) {
            // 時刻
            Text(event.date, style: .time)
                .font(.system(.subheadline, design: .monospaced).bold())
                .frame(width: 52, alignment: .trailing)
                .foregroundStyle(eventColor)

            // 種別アイコン
            ZStack {
                Circle()
                    .fill(eventColor.opacity(0.12))
                    .frame(width: 26, height: 26)
                Image(systemName: event.eventType.systemImage)
                    .font(.caption.bold())
                    .foregroundStyle(eventColor)
            }

            // 船舶情報
            VStack(alignment: .leading, spacing: 2) {
                Text(event.vessel.vesselName)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(event.eventType.label)
                        .font(.caption2)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(eventColor.opacity(0.1))
                        .foregroundStyle(eventColor)
                        .clipShape(Capsule())
                    VesselSizeBadge(vessel: event.vessel)
                }
            }

            Spacer()

            // 入港予定なら通知ボタン
            if event.eventType == .arrival {
                Button {
                    onScheduleNotification(event.vessel)
                } label: {
                    Image(systemName: "bell.badge")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .padding(6)
                        .background(Color.orange.opacity(0.1))
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// MARK: - Berth Gantt Chart

struct BerthGanttChart: View {
    let vessels: [VesselInfo]
    var onLongPressVessel: ((VesselInfo) -> Void)? = nil

    // Layout
    private let nameColW: CGFloat = 90   // 左固定の船名カラム幅
    private let dayW:     CGFloat = 80   // 1日あたりの幅（×10 = 800px）
    private let rowH:     CGFloat = 54
    private let dayHdrH:  CGFloat = 26
    private let hrHdrH:   CGFloat = 20

    private let pastDays:   Int = 3   // 過去に遡る日数
    private let futureDays: Int = 7   // 未来に表示する日数
    private var totalDays:  Int { pastDays + futureDays }

    private var hourW: CGFloat  { dayW / 24 }
    private var totalW: CGFloat { dayW * CGFloat(totalDays) }

    private static let jstCal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return c
    }()

    // 今日の0時から pastDays 日前を起点にする（JST固定）
    private var wStart: Date {
        // JST で「現在時刻」を取得し、その時点での日付の00:00:00を計算
        let now = Date()
        let components = Self.jstCal.dateComponents([.year, .month, .day], from: now)

        // JST カレンダーで components から Date を生成（これは JST の00:00:00を表す）
        guard let todayJST00 = Self.jstCal.date(from: components) else {
            return now
        }

        // pastDays 日前の00:00:00
        let startDate = Self.jstCal.date(byAdding: .day, value: -pastDays, to: todayJST00) ?? todayJST00
        return startDate
    }
    private var wEnd: Date {
        Self.jstCal.date(byAdding: .day, value: totalDays, to: wStart) ?? wStart
    }

    private func xFor(_ d: Date) -> CGFloat {
        let c = max(wStart, min(wEnd, d))
        return CGFloat(c.timeIntervalSince(wStart) / (Double(totalDays) * 24 * 3600)) * totalW
    }

    private var filtered: [VesselInfo] {
        vessels.filter {
            ($0.departureDate ?? wEnd)   > wStart &&
            ($0.arrivalDate   ?? wStart) < wEnd
        }
        .sorted { ($0.arrivalDate ?? .distantPast) < ($1.arrivalDate ?? .distantPast) }
    }

    private var chartH: CGFloat { CGFloat(max(filtered.count, 1)) * rowH }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            legend

            if filtered.isEmpty {
                Text("1週間以内の在泊予定なし")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity).padding(24)
            } else {
                HStack(alignment: .top, spacing: 0) {
                    // 左固定: 船名カラム
                    VStack(spacing: 0) {
                        Color.clear.frame(height: dayHdrH + hrHdrH)
                        ForEach(filtered) { v in nameCell(v) }
                    }
                    .frame(width: nameColW, height: dayHdrH + hrHdrH + chartH)

                    // 右スクロール: タイムライン
                    ScrollView(.horizontal, showsIndicators: true) {
                        ZStack(alignment: .topLeading) {
                            dayHeader
                            hrHeader.offset(y: dayHdrH)
                            rowBackgrounds.offset(y: dayHdrH + hrHdrH)
                            gridLines.offset(y: dayHdrH + hrHdrH)
                            vesselBars.offset(y: dayHdrH + hrHdrH)
                            nowLine
                        }
                        .frame(width: totalW, height: dayHdrH + hrHdrH + chartH)
                    }
                }
                .frame(height: dayHdrH + hrHdrH + chartH)
            }
        }
    }

    // MARK: Legend

    private var legend: some View {
        HStack(spacing: 16) {
            HStack(spacing: 5) {
                Capsule().fill(Color.red.opacity(0.78)).frame(width: 28, height: 10)
                Text("90m以上（大型）").font(.caption2).foregroundStyle(.secondary)
            }
            HStack(spacing: 5) {
                Capsule().fill(Color.blue.opacity(0.72)).frame(width: 28, height: 10)
                Text("90m未満").font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Label("横スクロール", systemImage: "arrow.left.and.right")
                .font(.caption2).foregroundStyle(.tertiary)
        }
    }

    // MARK: Name Cell（左固定カラム）

    private func nameCell(_ v: VesselInfo) -> some View {
        let color: Color = v.isLargeVessel ? .red : .blue
        return VStack(alignment: .leading, spacing: 2) {
            Text(v.vesselName)
                .font(.system(size: 10, weight: .semibold))
                .lineLimit(2)
                .foregroundStyle(color)
            if let loa = v.loaMeters {
                Text(String(format: "%.0fm", loa))
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            } else if !v.grossTonnage.isEmpty, v.grossTonnage != "null" {
                Text(v.grossTonnageFormatted)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.trailing, 4)
        .frame(width: nameColW, height: rowH, alignment: .leading)
    }

    // MARK: Day Header（日付行）

    private var dayHeader: some View {
        ZStack(alignment: .topLeading) {
            Color(.secondarySystemBackground).frame(width: totalW, height: dayHdrH)
            ForEach(0..<totalDays, id: \.self) { i in
                let d = wStart.addingTimeInterval(Double(i) * 86400)
                let isToday = Self.jstCal.isDateInToday(d)
                ZStack(alignment: .leading) {
                    if isToday {
                        Color.blue.opacity(0.1).frame(width: dayW, height: dayHdrH)
                    }
                    Rectangle()
                        .fill(Color(.separator).opacity(0.4))
                        .frame(width: 1, height: dayHdrH)
                    Text(dayLabel(d))
                        .font(.system(size: 10, weight: isToday ? .bold : .regular))
                        .foregroundStyle(isToday ? Color.blue : Color.primary)
                        .padding(.leading, 4)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(width: dayW, height: dayHdrH, alignment: .leading)
                }
                .offset(x: CGFloat(i) * dayW)
            }
        }
    }

    private func dayLabel(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.timeZone = TimeZone(identifier: "Asia/Tokyo")
        f.dateFormat = "M/d(E)"
        return f.string(from: d)
    }

    // MARK: Hour Header（6時間刻みサブヘッダー）

    private var hrHeader: some View {
        // 0, 6, 12, 18 の目盛り（各日×4）
        ZStack(alignment: .topLeading) {
            Color(.secondarySystemBackground).frame(width: totalW, height: hrHdrH)
            ForEach(0..<(totalDays * 4), id: \.self) { tick in
                let x = CGFloat(tick) * (dayW / 4)
                let hour = (tick % 4) * 6
                ZStack(alignment: .topLeading) {
                    Rectangle()
                        .fill(Color(.separator).opacity(hour == 0 ? 0.35 : 0.15))
                        .frame(width: 1, height: hrHdrH)
                    if hour > 0 {
                        Text("\(hour)h")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                            .offset(x: 2, y: 2)
                    }
                }
                .offset(x: x)
            }
        }
    }

    // MARK: Row Backgrounds（交互背景）

    private var rowBackgrounds: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(filtered.enumerated()), id: \.element.id) { i, _ in
                Rectangle()
                    .fill(i.isMultiple(of: 2)
                          ? Color(.systemBackground)
                          : Color(.secondarySystemBackground).opacity(0.5))
                    .frame(width: totalW, height: rowH)
                    .offset(y: CGFloat(i) * rowH)
            }
        }
        .frame(width: totalW, height: chartH)
    }

    // MARK: Grid Lines

    private var gridLines: some View {
        ZStack(alignment: .topLeading) {
            // 日単位の縦線
            ForEach(0..<(totalDays + 1), id: \.self) { i in
                Rectangle()
                    .fill(Color(.separator).opacity(0.3))
                    .frame(width: 1, height: chartH)
                    .offset(x: CGFloat(i) * dayW)
            }
            // 6時間ごとの補助線
            ForEach(1..<(totalDays * 4), id: \.self) { tick in
                if tick % 4 != 0 {
                    Rectangle()
                        .fill(Color(.separator).opacity(0.1))
                        .frame(width: 1, height: chartH)
                        .offset(x: CGFloat(tick) * (dayW / 4))
                }
            }
        }
        .frame(width: totalW, height: chartH)
    }

    // MARK: Vessel Bars

    private var vesselBars: some View {
        ZStack(alignment: .topLeading) {
            Color.clear.frame(width: totalW, height: chartH)
            ForEach(Array(filtered.enumerated()), id: \.element.id) { i, v in
                vesselBar(v, row: i)
            }
        }
        .frame(width: totalW, height: chartH)
    }

    private func vesselBar(_ v: VesselInfo, row: Int) -> some View {
        let arrX  = xFor(v.arrivalDate  ?? wStart)
        let depX  = xFor(v.departureDate ?? wEnd)
        let bw    = max(depX - arrX, 3)
        let barH: CGFloat = rowH - 12
        let yTop  = CGFloat(row) * rowH + 6
        let color: Color  = v.isLargeVessel ? .red : .blue
        let alpha: Double = v.isCurrentlyDocked ? 0.88 : 0.65

        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "ja_JP")
        fmt.timeZone = TimeZone(identifier: "Asia/Tokyo")
        fmt.dateFormat = "M/d H:mm"
        let arrStr = v.arrivalDate.map   { fmt.string(from: $0) } ?? "?"
        let depStr = v.departureDate.map { fmt.string(from: $0) } ?? "未定"

        return ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 5)
                .fill(color.opacity(alpha))
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(color.opacity(0.9), lineWidth: v.isCurrentlyDocked ? 1.5 : 0.5)
                )
                .frame(width: bw, height: barH)

            if bw > 28 {
                HStack(spacing: 0) {
                    // 入港時刻（左端）
                    Text(arrStr)
                        .font(.system(size: 8))
                        .foregroundStyle(.white.opacity(0.95))
                        .padding(.leading, 3)
                    Spacer(minLength: 0)
                    // 出港時刻（右端）
                    if bw > 90 {
                        Text(depStr)
                            .font(.system(size: 8))
                            .foregroundStyle(.white.opacity(0.82))
                            .padding(.trailing, 3)
                    }
                }
                .frame(width: bw, height: barH)
            }
        }
        .position(x: arrX + bw / 2, y: yTop + barH / 2)
        .onLongPressGesture(minimumDuration: 0.5) {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onLongPressVessel?(v)
        }
    }

    // MARK: Now Line（現在時刻）

    @ViewBuilder
    private var nowLine: some View {
        if Date() >= wStart, Date() <= wEnd {
            Rectangle()
                .fill(Color.orange.opacity(0.85))
                .frame(width: 2, height: dayHdrH + hrHdrH + chartH)
                .overlay(alignment: .top) {
                    Text("今")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(Color.orange)
                        .clipShape(Capsule())
                        .padding(.top, 2)
                }
                .offset(x: xFor(Date()) - 1)
        }
    }
}
