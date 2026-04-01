import SwiftUI
import Charts

struct TideView: View {
    @EnvironmentObject var vm: TideViewModel
    @State private var showDatePicker = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    locationSelector
                    currentTideCard
                    fishingScoreCard
                    tideChart
                    tideTableCard
                    moonPhaseCard
                }
                .padding()
            }
            .navigationTitle("潮汐情報")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showDatePicker.toggle()
                    } label: {
                        Label("日付選択", systemImage: "calendar")
                    }
                }
            }
            .sheet(isPresented: $showDatePicker) {
                DatePickerSheet(selectedDate: $vm.selectedDate) {
                    vm.recalculate()
                }
            }
        }
    }

    private var locationSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TideLocation.allCases, id: \.self) { location in
                    Button {
                        vm.updateLocation(location)
                    } label: {
                        Text(location.rawValue)
                            .font(.subheadline.bold())
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(vm.selectedLocation == location ? Color.blue : Color(.systemGray5))
                            .foregroundStyle(vm.selectedLocation == location ? .white : .primary)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private var currentTideCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("現在の潮位")
                    .font(.headline)
                Spacer()
                Text(vm.selectedDate, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .bottom, spacing: 4) {
                Text(String(format: "%.2f", vm.currentHeight))
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundStyle(.blue)
                Text("m")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)
            }

            if let info = vm.tideInfo {
                HStack {
                    Label("月齢 \(String(format: "%.1f", info.moonAge))日", systemImage: "moonphase.waning.gibbous")
                        .font(.caption)
                    Spacer()
                    Text(info.moonPhaseName)
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.purple.opacity(0.15))
                        .foregroundStyle(.purple)
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
        let score = vm.fishingScoreNow
        let color: Color = score.score >= 75 ? .green : score.score >= 50 ? .orange : .red
        let label = score.score >= 75 ? "釣れそう！" : score.score >= 50 ? "まずまず" : "厳しめ"

        return VStack(alignment: .leading, spacing: 8) {
            Text("今の時合いスコア")
                .font(.headline)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(label)
                        .font(.title2.bold())
                        .foregroundStyle(color)
                    if !score.reason.isEmpty {
                        Text(score.reason)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                ZStack {
                    Circle()
                        .stroke(Color(.systemGray5), lineWidth: 8)
                        .frame(width: 70, height: 70)
                    Circle()
                        .trim(from: 0, to: CGFloat(score.score) / 100.0)
                        .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 70, height: 70)
                        .rotationEffect(.degrees(-90))
                    Text("\(score.score)")
                        .font(.title3.bold())
                        .foregroundStyle(color)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8)
    }

    private var tideChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("潮位グラフ")
                .font(.headline)

            if #available(iOS 16.0, *) {
                Chart {
                    ForEach(vm.tideChartPoints) { point in
                        AreaMark(
                            x: .value("時刻", point.time),
                            y: .value("潮位", point.height)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue.opacity(0.4), .blue.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        LineMark(
                            x: .value("時刻", point.time),
                            y: .value("潮位", point.height)
                        )
                        .foregroundStyle(.blue)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .hour, count: 3)) { value in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.hour())
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel { Text("\(value.as(Double.self)?.formatted(.number.precision(.fractionLength(1))) ?? "")m") }
                    }
                }
                .frame(height: 180)
            } else {
                SimpleTideChartFallback(points: vm.tideChartPoints)
                    .frame(height: 180)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8)
    }

    private var tideTableCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("満潮・干潮")
                .font(.headline)

            ForEach(vm.tideExtrema) { point in
                HStack {
                    Image(systemName: point.type == .high ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                        .foregroundStyle(point.type == .high ? .blue : .orange)
                        .font(.title3)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(point.type?.rawValue ?? "")
                            .font(.subheadline.bold())
                        Text(point.time, style: .time)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(String(format: "%.2f m", point.height))
                        .font(.subheadline.bold())
                        .foregroundStyle(point.type == .high ? .blue : .orange)
                }
                .padding(.vertical, 4)
                if point.id != vm.tideExtrema.last?.id {
                    Divider()
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8)
    }

    private var moonPhaseCard: some View {
        guard let info = vm.tideInfo else { return AnyView(EmptyView()) }

        let moonEmoji: String
        switch info.moonPhase {
        case 0..<0.0625, 0.9375...1.0: moonEmoji = "🌑"
        case 0.0625..<0.25: moonEmoji = "🌒"
        case 0.25..<0.3125: moonEmoji = "🌓"
        case 0.3125..<0.4375: moonEmoji = "🌔"
        case 0.4375..<0.5625: moonEmoji = "🌕"
        case 0.5625..<0.75: moonEmoji = "🌖"
        case 0.75..<0.8125: moonEmoji = "🌗"
        default: moonEmoji = "🌘"
        }

        let tideType: String
        let distFromSyzygy = min(info.moonPhase, 1.0 - info.moonPhase)
        if distFromSyzygy < 0.1 { tideType = "大潮" }
        else if distFromSyzygy < 0.2 { tideType = "中潮" }
        else if distFromSyzygy < 0.3 { tideType = "小潮" }
        else { tideType = "長潮/若潮" }

        return AnyView(
            HStack(spacing: 16) {
                Text(moonEmoji)
                    .font(.system(size: 48))

                VStack(alignment: .leading, spacing: 4) {
                    Text(info.moonPhaseName)
                        .font(.headline)
                    Text("月齢 \(String(format: "%.1f", info.moonAge)) 日")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(tideType)
                        .font(.subheadline.bold())
                        .foregroundStyle(.blue)
                }
                Spacer()
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 8)
        )
    }
}

struct DatePickerSheet: View {
    @Binding var selectedDate: Date
    let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            DatePicker("日付を選択", selection: $selectedDate, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .navigationTitle("日付選択")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("確定") {
                            onConfirm()
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("キャンセル") { dismiss() }
                    }
                }
        }
    }
}

// Simple fallback chart for iOS 15
struct SimpleTideChartFallback: View {
    let points: [TidePoint]

    var body: some View {
        GeometryReader { geo in
            let heights = points.map { $0.height }
            let minH = heights.min() ?? 0
            let maxH = heights.max() ?? 2
            let range = maxH - minH

            Path { path in
                guard !points.isEmpty else { return }
                for (i, point) in points.enumerated() {
                    let x = CGFloat(i) / CGFloat(points.count - 1) * geo.size.width
                    let y = geo.size.height - CGFloat((point.height - minH) / range) * geo.size.height
                    if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                    else { path.addLine(to: CGPoint(x: x, y: y)) }
                }
            }
            .stroke(Color.blue, lineWidth: 2)
        }
    }
}
