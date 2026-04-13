import SwiftUI
import MapKit

struct SpotsView: View {
    @EnvironmentObject var berthUnlockStore: BerthUnlockStore
    @State private var selectedSpot: FishingSpot?
    @State private var searchText = ""
    @State private var filterDifficulty: FishingSpot.Difficulty? = nil
    @State private var showMap = false
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 35.35, longitude: 139.67),
        span: MKCoordinateSpan(latitudeDelta: 0.25, longitudeDelta: 0.25)
    )

    var filteredSpots: [FishingSpot] {
        FishingSpot.yokohamaYokosuka.filter { spot in
            let matchesSearch = searchText.isEmpty || spot.name.contains(searchText)
            let matchesDifficulty = filterDifficulty == nil || spot.difficulty == filterDifficulty
            let isVisible = !spot.isHidden || berthUnlockStore.isUnlocked
            return matchesSearch && matchesDifficulty && isVisible
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("表示", selection: $showMap) {
                    Text("リスト").tag(false)
                    Text("マップ").tag(true)
                }
                .pickerStyle(.segmented)
                .padding()

                if showMap {
                    mapView
                } else {
                    listView
                }
            }
            .navigationTitle("釣り場情報")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "釣り場を検索")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("すべて") { filterDifficulty = nil }
                        ForEach(FishingSpot.Difficulty.allCases, id: \.self) { d in
                            Button(d.rawValue) { filterDifficulty = d }
                        }
                    } label: {
                        Label("フィルター", systemImage: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            // リストからの遷移先
            .navigationDestination(for: FishingSpot.self) { spot in
                SpotDashboardView(spot: spot)
            }
            // マップピンからは引き続きシート
            .sheet(item: $selectedSpot) { spot in
                SpotDetailSheet(spot: spot)
            }
        }
    }

    private var listView: some View {
        List {
            if let diff = filterDifficulty {
                HStack {
                    Text("フィルター: \(diff.rawValue)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("クリア") { filterDifficulty = nil }
                        .font(.caption)
                }
                .listRowBackground(Color.clear)
            }

            ForEach(filteredSpots) { spot in
                NavigationLink(value: spot) {
                    SpotRow(spot: spot)
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.plain)
    }

    private var mapView: some View {
        Map(coordinateRegion: $region, annotationItems: filteredSpots) { spot in
            MapAnnotation(coordinate: spot.coordinate) {
                Button {
                    selectedSpot = spot
                } label: {
                    VStack(spacing: 2) {
                        ZStack {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 36, height: 36)
                            Image(systemName: "fish.fill")
                                .foregroundStyle(.white)
                                .font(.system(size: 16))
                        }
                        Text(spot.name)
                            .font(.caption2.bold())
                            .padding(.horizontal, 4)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

struct SpotRow: View {
    let spot: FishingSpot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(spot.name)
                        .font(.headline)
                }
                Spacer()
                Text(spot.difficulty.rawValue)
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(difficultyColor(spot.difficulty).opacity(0.15))
                    .foregroundStyle(difficultyColor(spot.difficulty))
                    .clipShape(Capsule())
            }

            Text(spot.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack(spacing: 16) {
                Label(spot.bestSeason, systemImage: "calendar")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Label(spot.bestTime, systemImage: "clock")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                if spot.parkingAvailable {
                    Label("駐車場", systemImage: "p.square.fill")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                }
                if spot.toiretAvailable {
                    Label("トイレ", systemImage: "toilet.fill")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func difficultyColor(_ difficulty: FishingSpot.Difficulty) -> Color {
        switch difficulty {
        case .beginner: return .green
        case .intermediate: return .orange
        case .advanced: return .red
        }
    }
}

struct SpotDetailSheet: View {
    let spot: FishingSpot
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var berthUnlockStore: BerthUnlockStore
    @EnvironmentObject var berthService: BerthMonitorService
    @State private var region: MKCoordinateRegion
    @State private var showBerthDetail = false

    private var showBerth: Bool {
        spot.name == "聖地コスモ" && berthUnlockStore.isUnlocked
    }

    init(spot: FishingSpot) {
        self.spot = spot
        _region = State(initialValue: MKCoordinateRegion(
            center: spot.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        ))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Map(coordinateRegion: $region, annotationItems: [spot]) { s in
                        MapMarker(coordinate: s.coordinate, tint: .blue)
                    }
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(spot.name)
                                    .font(.title2.bold())
                            }
                            Spacer()
                            difficultyBadge
                        }

                        Divider()

                        InfoRow(icon: "text.bubble", label: "特徴", value: spot.description)
                        InfoRow(icon: "calendar", label: "シーズン", value: spot.bestSeason)
                        InfoRow(icon: "clock", label: "時合い", value: spot.bestTime)
                        InfoRow(icon: "bus", label: "アクセス", value: spot.accessInfo)

                        Divider()

                        HStack(spacing: 20) {
                            FacilityBadge(available: spot.parkingAvailable, icon: "p.square.fill", label: "駐車場")
                            FacilityBadge(available: spot.toiretAvailable, icon: "toilet.fill", label: "トイレ")
                        }

                        Button {
                            openInMaps(spot: spot)
                        } label: {
                            Label("マップで開く", systemImage: "map.fill")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding()

                    // バース情報（聖地コスモ かつ 解除済みのみ）
                    if showBerth {
                        BerthStatusCard(berthService: berthService, onDetail: {
                            showBerthDetail = true
                        })
                        .padding(.horizontal)
                        .padding(.bottom)
                    }
                }
            }
            .navigationTitle(spot.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
            .sheet(isPresented: $showBerthDetail) {
                BerthMonitorView()
                    .environmentObject(berthService)
            }
            .onAppear {
                if showBerth && berthService.vessels.isEmpty {
                    Task { await berthService.fetch() }
                }
            }
        }
    }

    private var difficultyBadge: some View {
        let color: Color
        switch spot.difficulty {
        case .beginner: color = .green
        case .intermediate: color = .orange
        case .advanced: color = .red
        }
        return Text(spot.difficulty.rawValue)
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private func openInMaps(spot: FishingSpot) {
        let placemark = MKPlacemark(coordinate: spot.coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = spot.name
        mapItem.openInMaps()
    }
}

struct InfoRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline)
            }
        }
    }
}

struct FacilityBadge: View {
    let available: Bool
    let icon: String
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(available ? .blue : .secondary)
            Text(label)
                .font(.subheadline)
            Image(systemName: available ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(available ? .green : .red)
        }
    }
}

// MARK: - バースステータスカード（聖地コスモ専用・隠し機能）

struct BerthStatusCard: View {
    let berthService: BerthMonitorService
    let onDetail: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("住友大阪セメント岸壁", systemImage: "anchor")
                    .font(.subheadline.bold())
                Spacer()
                Button("詳細", action: onDetail)
                    .font(.caption.bold())
                    .foregroundStyle(.blue)
            }

            Divider()

            HStack(spacing: 10) {
                Image(systemName: berthService.isFishingAffected
                      ? "exclamationmark.triangle.fill"
                      : "checkmark.circle.fill")
                    .foregroundStyle(berthService.isFishingAffected ? .red : .green)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(berthService.isFishingAffected ? "釣りに影響あり（停泊中）" : "釣り可能")
                        .font(.subheadline.bold())
                        .foregroundStyle(berthService.isFishingAffected ? .red : .green)

                    if berthService.isFishingAffected, let clear = berthService.nextClearTime {
                        Text("出港予定: \(clear, style: .relative)後")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    } else if let next = berthService.upcomingVessels.first,
                              let arrival = next.arrivalDate {
                        Text("次の入港: \(arrival, style: .relative)後")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("当面の入港予定なし")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
                Text(berthService.isFishingAffected ? "🚫" : "🎣")
                    .font(.title2)
            }

            if let updated = berthService.lastUpdated {
                Text("更新: \(updated, style: .relative)前")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.06), radius: 6)
    }
}
