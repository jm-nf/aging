import SwiftUI

struct WeatherView: View {
    @EnvironmentObject var service: WeatherService

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if service.isLoading {
                        ProgressView("天気情報を取得中...")
                            .frame(maxWidth: .infinity)
                            .padding(40)
                    } else {
                        if let current = service.current {
                            currentWeatherCard(current)
                            fishingConditionCard(current)
                        }
                        if !service.forecast.isEmpty {
                            forecastCard
                        }
                        if let error = service.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding()
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("天気情報")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await service.fetchWeather() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .refreshable {
                await service.fetchWeather()
            }
        }
    }

    private func currentWeatherCard(_ data: WeatherData) -> some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("横浜")
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
                    icon: "humidity.fill",
                    title: "湿度",
                    value: "\(data.humidity)%"
                )
                Spacer()
                WeatherDetailItem(
                    icon: "wind",
                    title: "風速",
                    value: "\(String(format: "%.1f", data.windSpeed))m/s"
                )
                Spacer()
                WeatherDetailItem(
                    icon: "safari.fill",
                    title: "風向",
                    value: data.windDirectionName
                )
                Spacer()
                WeatherDetailItem(
                    icon: "eye.fill",
                    title: "視程",
                    value: "\(String(format: "%.0f", data.visibility))km"
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

    private var forecastCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("5日間予報")
                .font(.headline)

            ForEach(service.forecast, id: \.date) { item in
                HStack {
                    Text(item.dayOfWeek)
                        .font(.subheadline.bold())
                        .frame(width: 28, alignment: .leading)

                    Text(item.weatherEmoji)
                        .font(.title3)

                    Text(item.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if item.windSpeed > 0 {
                        Label(String(format: "%.1f", item.windSpeed), systemImage: "wind")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

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
                }
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
