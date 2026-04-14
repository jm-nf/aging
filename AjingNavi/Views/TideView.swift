import SwiftUI
import Charts

struct TideView: View {
    @EnvironmentObject var vm: TideViewModel
    @State private var showDatePicker = false

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(spacing: 16) {
                        locationSelector

                        if let error = vm.error {
                            errorCard(error)
                        }

                        if vm.isLoading {
                            loadingCard
                        } else if vm.tideInfo != nil {
                            currentTideCard
                            fishingScoreCard
                            tideChart
                            tideTableCard
                            moonPhaseCard
                        } else if vm.error == nil {
                            noDataCard
                        }
                    }
                    .padding()
                }

                if vm.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.1))
                }
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

    private var noDataCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "wave.3")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("潮汐データがまだ読み込まれていません")
                .font(.headline)
            Text("スポットを選択して、もう一度試してください")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8)
    }

    private var loadingCard: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text("潮汐データを取得中...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8)
    }

    private func errorCard(_ error: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.red)
                Text("エラーが発生しました")
                    .font(.headline)
                Spacer()
            }
            Text(error)
                .font(.caption)
                .foregroundStyle(.secondary)
            Button(action: { vm.recalculate() }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("再度取得")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .red.opacity(0.1), radius: 8)
    }

    private var locationSelector: some View {
        HStack {
            Image(systemName: "mappin.circle.fill")
                .foregroundStyle(.blue)
            Text("スポット")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Picker("", selection: $vm.selectedSpot) {
                ForEach(FishingSpot.yokohamaYokosuka) { spot in
                    Text(spot.name).tag(spot)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: vm.selectedSpot) {
                vm.recalculate()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 6)
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
        let tideType: String? = vm.tideInfo.map { i in
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
            CustomTideChart(points: vm.tideChartPoints, selectedDate: vm.selectedDate)
                .frame(height: 280)
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
        let distFromSyzygy = min(info.moonPhase, abs(info.moonPhase - 0.5), 1.0 - info.moonPhase)
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

// MARK: - Custom Tide Chart

struct CustomTideChart: View {
    let points: [TidePoint]
    let selectedDate: Date

    private var jstCal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return c
    }

    var body: some View {
        VStack(spacing: 0) {
            TideCanvasView(points: points, selectedDate: selectedDate, jstCal: jstCal)
            TideXAxisView(selectedDate: selectedDate, jstCal: jstCal)
                .frame(height: 20)
        }
    }
}

struct TideCanvasView: View {
    let points: [TidePoint]
    let selectedDate: Date
    let jstCal: Calendar

    var body: some View {
        GeometryReader { geo in
            let dayStart = jstCal.startOfDay(for: selectedDate)
            let dayEnd = jstCal.date(byAdding: .day, value: 1, to: dayStart)!
            let totalSec = dayEnd.timeIntervalSince(dayStart)
            let heights = points.map { $0.height }
            let minH = (heights.min() ?? -0.5) - 0.2
            let maxH = (heights.max() ?? 1.0) + 0.2
            let hRange = maxH - minH
            let now = Date()
            let isToday = jstCal.isDate(selectedDate, inSameDayAs: now)

            Canvas { ctx, size in
                // 1時間ごとのグリッド線
                for hour in 0...24 {
                    guard let tick = jstCal.date(byAdding: .hour, value: hour, to: dayStart) else { continue }
                    let x = CGFloat(tick.timeIntervalSince(dayStart) / totalSec) * size.width
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    let isMajor = hour % 3 == 0
                    ctx.stroke(path, with: .color(.gray.opacity(isMajor ? 0.35 : 0.15)), lineWidth: isMajor ? 0.8 : 0.3)
                }

                let sorted = points.sorted { $0.time < $1.time }
                guard sorted.count > 1 else { return }

                let fx = CGFloat(sorted[0].time.timeIntervalSince(dayStart) / totalSec) * size.width
                let fy = size.height - CGFloat((sorted[0].height - minH) / hRange) * size.height

                // エリア塗り
                var areaPath = Path()
                areaPath.move(to: CGPoint(x: fx, y: size.height))
                areaPath.addLine(to: CGPoint(x: fx, y: fy))
                for p in sorted.dropFirst() {
                    let px = CGFloat(p.time.timeIntervalSince(dayStart) / totalSec) * size.width
                    let py = size.height - CGFloat((p.height - minH) / hRange) * size.height
                    areaPath.addLine(to: CGPoint(x: px, y: py))
                }
                areaPath.addLine(to: CGPoint(x: CGFloat(sorted.last!.time.timeIntervalSince(dayStart) / totalSec) * size.width, y: size.height))
                areaPath.closeSubpath()
                ctx.fill(areaPath, with: .color(.blue.opacity(0.3)))

                // ライン
                var linePath = Path()
                linePath.move(to: CGPoint(x: fx, y: fy))
                for p in sorted.dropFirst() {
                    let px = CGFloat(p.time.timeIntervalSince(dayStart) / totalSec) * size.width
                    let py = size.height - CGFloat((p.height - minH) / hRange) * size.height
                    linePath.addLine(to: CGPoint(x: px, y: py))
                }
                ctx.stroke(linePath, with: .color(.blue), lineWidth: 2)

                // 現在時刻ライン（赤い点線）
                if isToday {
                    let nowX = CGFloat(now.timeIntervalSince(dayStart) / totalSec) * size.width
                    if nowX >= 0 && nowX <= size.width {
                        var nowPath = Path()
                        nowPath.move(to: CGPoint(x: nowX, y: 0))
                        nowPath.addLine(to: CGPoint(x: nowX, y: size.height))
                        ctx.stroke(nowPath, with: .color(.red.opacity(0.8)),
                                   style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    }
                }
            }
        }
    }
}

struct TideXAxisView: View {
    let selectedDate: Date
    let jstCal: Calendar

    var body: some View {
        GeometryReader { geo in
            let dayStart = jstCal.startOfDay(for: selectedDate)
            let dayEnd = jstCal.date(byAdding: .day, value: 1, to: dayStart)!
            let totalSec = dayEnd.timeIntervalSince(dayStart)

            ForEach([0, 3, 6, 9, 12, 15, 18, 21, 24], id: \.self) { hour in
                if let tick = jstCal.date(byAdding: .hour, value: hour, to: dayStart) {
                    let x = CGFloat(tick.timeIntervalSince(dayStart) / totalSec) * geo.size.width
                    Text("\(hour)")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .position(x: x, y: 10)
                }
            }
        }
    }
}
