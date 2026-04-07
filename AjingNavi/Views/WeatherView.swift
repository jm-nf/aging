import SwiftUI
import Charts

struct WeatherView: View {
    @EnvironmentObject var service: WeatherManager
    @State private var selectedForecastDay: ForecastItem? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    spotPickerCard

                    if service.isLoading {
                        ProgressView("天気情報を取得中...")
                            .frame(maxWidth: .infinity)
                            .padding(40)
                    } else {
                        if let current = service.current {
                            currentWeatherCard(current)
                            fishingConditionCard(current)
                        }
                        if !service.seaTemperature.isEmpty {
                            seaTemperatureCard
                        }
                        if !service.hourlyForecast.isEmpty {
                            hourlyForecastCard
                        }
                        if !service.forecast.isEmpty {
                            forecastCard
                        }
                        if let error = service.errorMessage {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                Text(error)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("天気情報")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 8) {
                        Text(service.dataSource)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Button {
                            Task { await service.fetchWeather() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
            .refreshable {
                await service.fetchWeather()
            }
            .sheet(item: $selectedForecastDay) { day in
                DayHourlySheet(
                    day: day,
                    items: service.fullHourlyForecast.filter {
                        Calendar.current.isDate($0.date, inSameDayAs: day.date)
                    }
                )
            }
        }
    }

    private var spotPickerCard: some View {
        HStack {
            Image(systemName: "mappin.circle.fill")
                .foregroundStyle(.blue)
            Text("釣り場")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Picker("", selection: $service.selectedSpot) {
                ForEach(FishingSpot.yokohamaYokosuka) { spot in
                    Text(spot.name).tag(spot)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: service.selectedSpot) {
                Task { await service.fetchWeather() }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 6)
    }

    private func currentWeatherCard(_ data: WeatherData) -> some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(service.locationName)
                        .font(.headline)
                    Text(Date(), style: .time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(data.weatherEmoji)
                    .font(.system(size: 48))
            }

            HStack(alignment: .bottom, spacing: 4) {
                Text(String(format: "%.1f°", data.temperature))
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("体感 \(String(format: "%.1f°", data.feelsLike))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(data.description)
                        .font(.subheadline.bold())
                }
            }

            Divider()

            HStack {
                WeatherDetailItem(
                    icon: "wind",
                    title: "風速",
                    value: "\(String(format: "%.1f", data.windSpeed))m/s"
                )
                Spacer()
                WeatherDetailItem(
                    icon: "wind",
                    title: "瞬間",
                    value: data.windGust > 0 ? "\(String(format: "%.1f", data.windGust))m/s" : "-"
                )
                Spacer()
                WeatherDetailItem(
                    icon: "safari.fill",
                    title: "風向",
                    value: data.windDirectionName
                )
                Spacer()
                WeatherDetailItem(
                    icon: "barometer",
                    title: "気圧",
                    value: "\(Int(data.pressure))hPa"
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8)
    }

    private func fishingConditionCard(_ data: WeatherData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("釣り条件")
                .font(.headline)

            VStack(spacing: 8) {
                FishingConditionRow(
                    title: "風",
                    status: data.fishingWindRating,
                    detail: "\(data.windDirectionName)の風 \(String(format: "%.1f", data.windSpeed))m/s",
                    isGood: data.windSpeed < 6
                )
                Divider()
                FishingConditionRow(
                    title: "視程",
                    status: data.visibility > 5 ? "良好" : "悪め",
                    detail: "\(String(format: "%.0f", data.visibility))km",
                    isGood: data.visibility > 5
                )
                Divider()
                FishingConditionRow(
                    title: "気圧",
                    status: data.pressure > 1005 ? "安定" : "低め",
                    detail: "\(data.pressure) hPa",
                    isGood: data.pressure > 1005
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8)
    }

    // MARK: - Hourly Forecast

    private var hourlyForecastCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("時間別予報（ECMWF・1時間刻み）", systemImage: "clock.fill")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(service.hourlyForecast) { item in
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

    // MARK: - 海水温グラフ

    private var seaTemperatureCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("海水温トレンド", systemImage: "thermometer.medium")
                    .font(.headline)
                Spacer()
                if let latest = service.seaTemperature.last(where: { !$0.isForecast }) {
                    Text(String(format: "%.1f°C", latest.temp))
                        .font(.title3.bold())
                        .foregroundStyle(.cyan)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                Chart {
                    // 実績（過去）
                    ForEach(service.seaTemperature.filter { !$0.isForecast }) { point in
                        LineMark(
                            x: .value("日時", point.date),
                            y: .value("水温", point.temp),
                            series: .value("系列", "実績")
                        )
                        .foregroundStyle(Color.cyan)
                        .lineStyle(StrokeStyle(lineWidth: 2))

                        AreaMark(
                            x: .value("日時", point.date),
                            y: .value("水温", point.temp)
                        )
                        .foregroundStyle(LinearGradient(
                            colors: [.cyan.opacity(0.2), .clear],
                            startPoint: .top, endPoint: .bottom
                        ))
                    }

                    // 予報（境界点を含めて接続）
                    ForEach(service.seaTemperature.filter { point in
                        point.isForecast ||
                        point.date == service.seaTemperature.filter { !$0.isForecast }.last?.date
                    }) { point in
                        LineMark(
                            x: .value("日時", point.date),
                            y: .value("水温", point.temp),
                            series: .value("系列", "予報")
                        )
                        .foregroundStyle(Color.orange.opacity(0.8))
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))
                    }

                    // 現在時刻
                    RuleMark(x: .value("現在", Date()))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .foregroundStyle(.secondary.opacity(0.6))
                        .annotation(position: .top, alignment: .leading) {
                            Text("今")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 1)) { value in
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
                .frame(width: CGFloat(service.seaTemperature.count) * 20 + 40, height: 160)
            }

            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Rectangle().fill(Color.cyan).frame(width: 16, height: 2)
                    Text("実績").font(.caption2).foregroundStyle(.secondary)
                }
                HStack(spacing: 4) {
                    Rectangle().fill(Color.orange.opacity(0.8)).frame(width: 16, height: 2)
                    Text("予報").font(.caption2).foregroundStyle(.secondary)
                }
                if let minT = service.seaTemperature.map(\.temp).min(),
                   let maxT = service.seaTemperature.map(\.temp).max() {
                    Spacer()
                    Text(String(format: "%.1f° – %.1f°C", minT, maxT))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8)
    }

    private var forecastCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("5日間予報")
                .font(.headline)

            ForEach(service.forecast) { item in
                Button {
                    selectedForecastDay = item
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.dayOfWeek)
                                .font(.subheadline.bold())
                            Text(item.dateLabel)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(width: 36, alignment: .leading)

                        Text(item.weatherEmoji)
                            .font(.title3)

                        Text(item.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Label(String(format: "%.1f m/s", item.windSpeed), systemImage: "wind")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 4) {
                            Text(String(format: "%.0f°", item.tempMax))
                                .font(.subheadline.bold())
                                .foregroundStyle(.red.opacity(0.8))
                            Text("/")
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.0f°", item.tempMin))
                                .font(.subheadline)
                                .foregroundStyle(.blue.opacity(0.8))
                        }

                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.vertical, 4)
                if item.date != service.forecast.last?.date {
                    Divider()
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8)
    }
}

struct WeatherDetailItem: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
            Text(value)
                .font(.subheadline.bold())
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

struct FishingConditionRow: View {
    let title: String
    let status: String
    let detail: String
    let isGood: Bool

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .frame(width: 40, alignment: .leading)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(status)
                .font(.caption.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isGood ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                .foregroundStyle(isGood ? .green : .red)
                .clipShape(Capsule())
        }
    }
}

// MARK: - Hourly Forecast Cell

struct HourlyForecastCell: View {
    let item: HourlyForecastItem

    private var windColor: Color {
        switch item.windSpeed {
        case ..<3:  return .green
        case ..<6:  return .yellow
        case ..<10: return .orange
        default:    return .red
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            Text(item.hourLabel)
                .font(.caption2.bold())
                .foregroundStyle(.secondary)

            Text(item.weatherEmoji)
                .font(.title3)

            Text(String(format: "%.0f°", item.temp))
                .font(.subheadline.bold())

            Divider()

            // 風速
            HStack(spacing: 2) {
                Image(systemName: "wind")
                    .font(.caption2)
                    .foregroundStyle(windColor)
                Text(String(format: "%.1f", item.windSpeed))
                    .font(.caption2.bold())
                    .foregroundStyle(windColor)
            }

            // 瞬間風速
            if item.windGust > 0 {
                Text(String(format: "(%.1f)", item.windGust))
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }

            // 風向
            Text(item.windDirectionName)
                .font(.caption2)
                .foregroundStyle(.secondary)

            // 降水量
            if item.precipitation > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "drop.fill")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                    Text(String(format: "%.1f", item.precipitation))
                        .font(.caption2)
                        .foregroundStyle(.blue)
                }
            } else {
                Text("-")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 62)
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - 日別 時間別予報シート

struct DayHourlySheet: View {
    let day: ForecastItem
    let items: [HourlyForecastItem]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "clock.badge.questionmark")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("この日の時間別データがありません")
                            .foregroundStyle(.secondary)
                        Text("WeatherKitの時間別予報は取得できる範囲が限られます")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(40)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            // 日サマリー
                            HStack(spacing: 16) {
                                Text(day.weatherEmoji).font(.system(size: 40))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(day.description).font(.subheadline.bold())
                                    HStack(spacing: 6) {
                                        Text(String(format: "最高 %.0f°", day.tempMax))
                                            .foregroundStyle(.red.opacity(0.8))
                                        Text(String(format: "最低 %.0f°", day.tempMin))
                                            .foregroundStyle(.blue.opacity(0.8))
                                    }
                                    .font(.caption)
                                }
                                Spacer()
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                            // 時間別セル
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(items) { item in
                                        HourlyForecastCell(item: item)
                                    }
                                }
                                .padding(.horizontal, 2)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("\(day.dateLabel)(\(day.dayOfWeek)) 時間別予報")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}
