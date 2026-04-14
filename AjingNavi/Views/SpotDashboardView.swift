import SwiftUI
import Charts
import MapKit

// MARK: - SpotDashboardRoot（タブから直接表示されるラッパー）

struct SpotDashboardRoot: View {
    @EnvironmentObject var spotStore: SpotSelectionStore
    @EnvironmentObject var berthUnlockStore: BerthUnlockStore

    private var visibleSpots: [FishingSpot] {
        FishingSpot.yokohamaYokosuka.filter { !$0.isHidden || berthUnlockStore.isUnlocked }
    }

    var body: some View {
        NavigationStack {
            SpotDashboardView(spot: spotStore.selectedSpot)
                .id(spotStore.selectedSpot.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Menu {
                            ForEach(visibleSpots) { spot in
                                Button {
                                    spotStore.selectedSpot = spot
                                } label: {
                                    if spot.name == spotStore.selectedSpot.name {
                                        Label(spot.name, systemImage: "checkmark")
                                    } else {
                                        Text(spot.name)
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(spotStore.selectedSpot.name)
                                    .font(.headline)
                                Image(systemName: "chevron.down")
                                    .font(.caption.weight(.semibold))
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                }
        }
    }
}

// MARK: - SpotDashboardView（ポイント詳細ダッシュボード）

// ポイント詳細ダッシュボード（潮汐＋天気＋バースを1画面に統合）
struct SpotDashboardView: View {
    let spot: FishingSpot

    @StateObject private var tideVM: TideViewModel
    @StateObject private var weatherManager: WeatherManager
    @EnvironmentObject var berthUnlockStore: BerthUnlockStore
    @EnvironmentObject var berthService: BerthMonitorService

    @State private var showDatePicker = false
    @State private var showBerthDetail = false
    @State private var selectedForecastDay: ForecastItem? = nil

    private var showBerth: Bool {
        spot.name == "聖地コスモ" && berthUnlockStore.isUnlocked
    }

    init(spot: FishingSpot) {
        self.spot = spot
        _tideVM = StateObject(wrappedValue: TideViewModel(spot: spot))
        _weatherManager = StateObject(wrappedValue: WeatherManager(spot: spot))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                // MARK: ポイント概要カード
                spotHeaderCard

                // MARK: 潮汐セクション
                sectionHeader(title: "潮汐情報", icon: "water.waves")
                currentTideCard
                fishingScoreCard
                tideChartCard
                tideTableCard
                moonPhaseCard

                // MARK: 天気セクション
                sectionHeader(title: "天気情報", icon: "cloud.sun.fill")
                if weatherManager.isLoading {
                    ProgressView("天気情報を取得中...")
                        .frame(maxWidth: .infinity).padding(40)
                } else {
                    if let current = weatherManager.current {
                        currentWeatherCard(current)
                        fishingConditionCard(current)
                    }
                    if !weatherManager.seaTemperature.isEmpty { seaTemperatureCard }
                    if !weatherManager.hourlyForecast.isEmpty { hourlyForecastCard }
                    if !weatherManager.forecast.isEmpty { forecastCard }
                    if let err = weatherManager.errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                            Text(err).font(.caption).foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }

                // MARK: バースセクション（聖地コスモかつ解除済みのみ）
                if showBerth {
                    sectionHeader(title: "バース状況", icon: "anchor")
                    BerthStatusCard(berthService: berthService, onDetail: { showBerthDetail = true })
                }
            }
            .padding()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    // 天気データソース
                    Text(weatherManager.dataSource)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    // 日付選択（潮汐用）
                    Button {
                        showDatePicker.toggle()
                    } label: {
                        Image(systemName: "calendar")
                    }
                }
            }
        }
        .sheet(isPresented: $showDatePicker) {
            DatePickerSheet(selectedDate: $tideVM.selectedDate) {
                tideVM.recalculate()
            }
        }
        .sheet(isPresented: $showBerthDetail) {
            BerthMonitorView().environmentObject(berthService)
        }
        .sheet(item: $selectedForecastDay) { day in
            DayHourlySheet(
                day: day,
                items: weatherManager.fullHourlyForecast.filter {
                    Calendar.current.isDate($0.date, inSameDayAs: day.date)
                },
                location: tideVM.selectedSpot.tideLocation
            )
        }
        .task {
            await weatherManager.fetchWeather()
            if showBerth && berthService.vessels.isEmpty {
                await berthService.fetch()
            }
        }
    }

    // MARK: - セクションヘッダー

    private func sectionHeader(title: String, icon: String) -> some View {
        HStack {
            Label(title, systemImage: icon)
                .font(.title3.bold())
            Spacer()
        }
        .padding(.top, 4)
    }

    // MARK: - ポイント概要カード

    private var spotHeaderCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Label(spot.bestSeason, systemImage: "calendar")
                        .font(.caption).foregroundStyle(.secondary)
                    Label(spot.bestTime, systemImage: "clock")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 12) {
                    FacilityBadge(available: spot.parkingAvailable, icon: "p.square.fill", label: "駐車場")
                    FacilityBadge(available: spot.toiretAvailable, icon: "toilet.fill", label: "トイレ")
                }
            }
            Text(spot.description)
                .font(.subheadline).foregroundStyle(.secondary)

            Button {
                let placemark = MKPlacemark(coordinate: spot.coordinate)
                let item = MKMapItem(placemark: placemark)
                item.name = spot.name
                item.openInMaps()
            } label: {
                Label("マップで開く", systemImage: "map.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8)
    }

    // MARK: - 潮汐カード群

    private var currentTideCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("現在の潮位").font(.headline)
                Spacer()
                Text(tideVM.selectedDate, style: .date)
                    .font(.caption).foregroundStyle(.secondary)
            }
            HStack(alignment: .bottom, spacing: 4) {
                Text(String(format: "%.2f", tideVM.currentHeight))
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundStyle(.blue)
                Text("m").font(.title2).foregroundStyle(.secondary).padding(.bottom, 8)
            }
            if let info = tideVM.tideInfo {
                HStack {
                    Label("月齢 \(String(format: "%.1f", info.moonAge))日", systemImage: "moonphase.waning.gibbous")
                        .font(.caption)
                    Spacer()
                    Text(info.moonPhaseName)
                        .font(.caption.bold())
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.purple.opacity(0.15)).foregroundStyle(.purple)
                        .clipShape(Capsule())
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8)
    }

    private var fishingScoreCard: some View {
        let seaTemp = weatherManager.seaTemperature.last(where: { !$0.isForecast })?.temp
        let score = tideVM.fishingScore(seaTemp: seaTemp)
        let color: Color = score.score >= 75 ? .green : score.score >= 50 ? .orange : .red
        let label = score.score >= 75 ? "釣れそう！" : score.score >= 50 ? "まずまず" : "厳しめ"

        return VStack(alignment: .leading, spacing: 8) {
            Text("今の時合いスコア").font(.headline)
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(label).font(.title2.bold()).foregroundStyle(color)
                    if !score.reason.isEmpty {
                        Text(score.reason).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                ZStack {
                    Circle().stroke(Color(.systemGray5), lineWidth: 8).frame(width: 70, height: 70)
                    Circle()
                        .trim(from: 0, to: CGFloat(score.score) / 100.0)
                        .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 70, height: 70).rotationEffect(.degrees(-90))
                    Text("\(score.score)").font(.title3.bold()).foregroundStyle(color)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8)
    }

    private var tideChartCard: some View {
        let tideType: String? = tideVM.tideInfo.map { i in
            let d = min(i.moonPhase, abs(i.moonPhase - 0.5), 1.0 - i.moonPhase)
            return d < 0.1 ? "大潮" : d < 0.2 ? "中潮" : d < 0.3 ? "小潮" : "長潮/若潮"
        }
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("潮位グラフ").font(.headline)
                Spacer()
                if let type = tideType {
                    Text(type)
                        .font(.caption.bold())
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.blue.opacity(0.15))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())
                }
            }
            CustomTideChart(points: tideVM.tideChartPoints, selectedDate: tideVM.selectedDate)
                .frame(height: 220)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8)
    }

    private var tideTableCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("満潮・干潮").font(.headline)
            ForEach(tideVM.tideExtrema) { point in
                HStack {
                    Image(systemName: point.type == .high ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                        .foregroundStyle(point.type == .high ? .blue : .orange).font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(point.type?.rawValue ?? "").font(.subheadline.bold())
                        Text(point.time, style: .time).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(String(format: "%.2f m", point.height))
                        .font(.subheadline.bold())
                        .foregroundStyle(point.type == .high ? .blue : .orange)
                }
                .padding(.vertical, 4)
                if point.id != tideVM.tideExtrema.last?.id { Divider() }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8)
    }

    @ViewBuilder
    private var moonPhaseCard: some View {
        if let info = tideVM.tideInfo {
            let moonEmoji: String = {
                switch info.moonPhase {
                case 0..<0.0625, 0.9375...1.0: return "🌑"
                case 0.0625..<0.25: return "🌒"
                case 0.25..<0.3125: return "🌓"
                case 0.3125..<0.4375: return "🌔"
                case 0.4375..<0.5625: return "🌕"
                case 0.5625..<0.75: return "🌖"
                case 0.75..<0.8125: return "🌗"
                default: return "🌘"
                }
            }()
            let d = min(info.moonPhase, abs(info.moonPhase - 0.5), 1.0 - info.moonPhase)
            let tideType = d < 0.1 ? "大潮" : d < 0.2 ? "中潮" : d < 0.3 ? "小潮" : "長潮/若潮"

            HStack(spacing: 16) {
                Text(moonEmoji).font(.system(size: 48))
                VStack(alignment: .leading, spacing: 4) {
                    Text(info.moonPhaseName).font(.headline)
                    Text("月齢 \(String(format: "%.1f", info.moonAge)) 日")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text(tideType).font(.subheadline.bold()).foregroundStyle(.blue)
                }
                Spacer()
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 8)
        }
    }

    // MARK: - 天気カード群

    private func currentWeatherCard(_ data: WeatherData) -> some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(Date(), style: .time).font(.caption).foregroundStyle(.secondary)
                    Text(data.description).font(.subheadline.bold())
                }
                Spacer()
                Text(data.weatherEmoji).font(.system(size: 48))
            }
            HStack(alignment: .bottom, spacing: 4) {
                Text(String(format: "%.1f°", data.temperature))
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("体感 \(String(format: "%.1f°", data.feelsLike))")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text("湿度 \(data.humidity)%")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Divider()
            HStack {
                WeatherDetailItem(icon: "wind", title: "風速",
                                  value: "\(String(format: "%.1f", data.windSpeed))m/s")
                Spacer()
                WeatherDetailItem(icon: "wind", title: "瞬間",
                                  value: data.windGust > 0 ? "\(String(format: "%.1f", data.windGust))m/s" : "-")
                Spacer()
                WeatherDetailItem(icon: "safari.fill", title: "風向", value: data.windDirectionName)
                Spacer()
                WeatherDetailItem(icon: "barometer", title: "気圧",
                                  value: "\(Int(data.pressure))hPa")
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8)
    }

    private func fishingConditionCard(_ data: WeatherData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("釣り条件").font(.headline)
            VStack(spacing: 8) {
                FishingConditionRow(title: "風", status: data.fishingWindRating,
                    detail: "\(data.windDirectionName)の風 \(String(format: "%.1f", data.windSpeed))m/s",
                    isGood: data.windSpeed < 6)
                Divider()
                FishingConditionRow(title: "視程",
                    status: data.visibility > 5 ? "良好" : "悪め",
                    detail: "\(String(format: "%.0f", data.visibility))km",
                    isGood: data.visibility > 5)
                Divider()
                FishingConditionRow(title: "気圧",
                    status: data.pressure > 1005 ? "安定" : "低め",
                    detail: "\(Int(data.pressure)) hPa",
                    isGood: data.pressure > 1005)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8)
    }

    private var hourlyForecastCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("時間別予報", systemImage: "clock.fill").font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(weatherManager.hourlyForecast) { item in
                        HourlyForecastCell(item: item)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8)
    }

    private var seaTemperatureCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("海水温トレンド", systemImage: "thermometer.medium").font(.headline)
                Spacer()
                if let latest = weatherManager.seaTemperature.last(where: { !$0.isForecast }) {
                    Text(String(format: "%.1f°C", latest.temp))
                        .font(.title3.bold()).foregroundStyle(.cyan)
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                Chart {
                    ForEach(weatherManager.seaTemperature.filter { !$0.isForecast }) { pt in
                        LineMark(x: .value("日時", pt.date), y: .value("水温", pt.temp),
                                 series: .value("系列", "実績"))
                            .foregroundStyle(Color.cyan).lineStyle(StrokeStyle(lineWidth: 2))
                        AreaMark(x: .value("日時", pt.date), y: .value("水温", pt.temp))
                            .foregroundStyle(LinearGradient(
                                colors: [.cyan.opacity(0.2), .clear], startPoint: .top, endPoint: .bottom))
                    }
                    ForEach(weatherManager.seaTemperature.filter { pt in
                        pt.isForecast ||
                        pt.date == weatherManager.seaTemperature.filter { !$0.isForecast }.last?.date
                    }) { pt in
                        LineMark(x: .value("日時", pt.date), y: .value("水温", pt.temp),
                                 series: .value("系列", "予報"))
                            .foregroundStyle(Color.orange.opacity(0.8))
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))
                    }
                    RuleMark(x: .value("現在", Date()))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .foregroundStyle(.secondary.opacity(0.6))
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 1)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.twoDigits).day(.twoDigits))
                    }
                }
                .chartYAxis {
                    AxisMarks(values: .stride(by: 5)) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            Text("\(value.as(Double.self).map { String(format: "%.0f°", $0) } ?? "")")
                        }
                    }
                }
                .chartLegend(.hidden)
                .frame(width: CGFloat(weatherManager.seaTemperature.count) * 20 + 40, height: 160)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8)
    }

    private var forecastCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("5日間予報").font(.headline)
            ForEach(weatherManager.forecast) { item in
                Button { selectedForecastDay = item } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.dayOfWeek).font(.subheadline.bold())
                            Text(item.dateLabel).font(.caption2).foregroundStyle(.secondary)
                        }
                        .frame(width: 36, alignment: .leading)
                        Text(item.weatherEmoji).font(.title3)
                        Text(item.description).font(.caption).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        VStack(alignment: .trailing, spacing: 1) {
                            Label(String(format: "%.1f m/s", item.windSpeed), systemImage: "wind")
                                .font(.caption2).foregroundStyle(.secondary)
                            if item.windGust > 0 {
                                Text(String(format: "(%.1f)", item.windGust))
                                    .font(.caption2).foregroundStyle(.orange)
                            }
                        }
                        HStack(spacing: 4) {
                            Text(String(format: "%.0f°", item.tempMax))
                                .font(.subheadline.bold()).foregroundStyle(.red.opacity(0.8))
                            Text("/").foregroundStyle(.secondary)
                            Text(String(format: "%.0f°", item.tempMin))
                                .font(.subheadline).foregroundStyle(.blue.opacity(0.8))
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption2).foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.vertical, 4)
                if item.date != weatherManager.forecast.last?.date { Divider() }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8)
    }
}

// MARK: - FacilityBadge

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

// MARK: - BerthStatusCard（聖地コスモ専用・隠し機能）

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
