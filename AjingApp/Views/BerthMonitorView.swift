import SwiftUI

struct BerthMonitorView: View {
    @EnvironmentObject var service: BerthMonitorService
    @State private var showNotificationAlert = false
    @State private var autoRefreshTimer: Timer?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    statusBanner
                    controlBar
                    if service.isLoading {
                        loadingView
                    } else {
                        if service.vessels.isEmpty {
                            emptyState
                        } else {
                            currentlyDockedSection
                            upcomingSection
                            allVesselsSection
                        }
                    }
                    if let error = service.errorMessage {
                        errorView(error)
                    }
                    dataSourceNote
                }
                .padding()
            }
            .navigationTitle("MTK0Cバース監視")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
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
            .refreshable {
                await service.fetch()
            }
            .onAppear {
                if service.vessels.isEmpty {
                    Task { await service.fetch() }
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
                        Text("MTK0Cバースに船が停泊中")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if !service.upcomingVessels.isEmpty {
                        let next = service.upcomingVessels[0]
                        if let arrival = next.arrivalDate {
                            Text("次の入港: \(arrival, style: .relative)後")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    } else {
                        Text("MTK0Cバースは空き状態")
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

    // MARK: - Currently Docked

    @ViewBuilder
    private var currentlyDockedSection: some View {
        if !service.currentlyDockedVessels.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Label("現在停泊中", systemImage: "anchor.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.red)

                ForEach(service.currentlyDockedVessels) { vessel in
                    VesselCard(vessel: vessel)
                }
            }
        }
    }

    // MARK: - Upcoming

    @ViewBuilder
    private var upcomingSection: some View {
        if !service.upcomingVessels.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Label("入港予定", systemImage: "arrow.down.to.line.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)

                ForEach(service.upcomingVessels) { vessel in
                    VesselCard(vessel: vessel) {
                        service.scheduleArrivalNotification(for: vessel)
                    }
                }
            }
        }
    }

    // MARK: - All Vessels

    @ViewBuilder
    private var allVesselsSection: some View {
        let others = service.vessels.filter { !$0.isCurrentlyDocked && !$0.isUpcoming }
        if !others.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Label("その他（出港済み等）", systemImage: "list.bullet")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                ForEach(others) { vessel in
                    VesselCard(vessel: vessel)
                }
            }
        }
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
            Text("MTK0Cバースに予定船舶なし")
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

            if !vessel.nationality.isEmpty || !vessel.grossTonnage.isEmpty || !vessel.purpose.isEmpty {
                HStack(spacing: 12) {
                    if !vessel.nationality.isEmpty {
                        Label(vessel.nationality, systemImage: "flag.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if !vessel.grossTonnage.isEmpty {
                        Label("\(vessel.grossTonnage)GT", systemImage: "scalemass")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if !vessel.purpose.isEmpty {
                        Label(vessel.purpose, systemImage: "doc.text")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
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
