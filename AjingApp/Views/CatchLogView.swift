import SwiftUI

struct CatchLogView: View {
    @EnvironmentObject var store: CatchRecordStore
    @State private var showAddSheet = false

    var body: some View {
        NavigationStack {
            Group {
                if store.records.isEmpty {
                    emptyState
                } else {
                    recordList
                }
            }
            .navigationTitle("釣果記録")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddCatchSheet { record in
                    store.add(record)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "fish")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Text("釣果記録がありません")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("右上の＋ボタンで記録を追加できます")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button {
                showAddSheet = true
            } label: {
                Label("記録を追加", systemImage: "plus.circle.fill")
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var recordList: some View {
        List {
            statsSection
            ForEach(store.records) { record in
                CatchRecordRow(record: record)
            }
            .onDelete { offsets in
                store.delete(at: offsets)
            }
        }
        .listStyle(.insetGrouped)
    }

    private var statsSection: some View {
        Section("統計") {
            HStack {
                StatCard(
                    title: "総釣行数",
                    value: "\(store.records.count)回",
                    icon: "calendar.badge.checkmark"
                )
                Spacer()
                StatCard(
                    title: "総釣果",
                    value: "\(store.records.map(\.fishCount).reduce(0, +))匹",
                    icon: "fish.fill"
                )
                Spacer()
                StatCard(
                    title: "最大サイズ",
                    value: "\(String(format: "%.0f", store.records.map(\.maxSize).max() ?? 0))cm",
                    icon: "ruler"
                )
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
            Text(value)
                .font(.headline.bold())
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct CatchRecordRow: View {
    let record: CatchRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(record.spotName.isEmpty ? "不明な釣り場" : record.spotName)
                        .font(.headline)
                    Text(record.date, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(record.fishCount)匹")
                        .font(.title3.bold())
                        .foregroundStyle(.blue)
                    if record.maxSize > 0 {
                        Text("最大 \(String(format: "%.0f", record.maxSize))cm")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack(spacing: 12) {
                if !record.weather.isEmpty {
                    Label(record.weather, systemImage: "cloud.sun")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !record.lure.isEmpty {
                    Label(record.lure, systemImage: "paperclip")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !record.tide.isEmpty {
                    Label(record.tide, systemImage: "water.waves")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !record.memo.isEmpty {
                Text(record.memo)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

struct AddCatchSheet: View {
    let onSave: (CatchRecord) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var spotName = ""
    @State private var date = Date()
    @State private var fishCount = 0
    @State private var maxSize = 0.0
    @State private var weather = ""
    @State private var windDirection = ""
    @State private var tide = ""
    @State private var lure = ""
    @State private var memo = ""

    private let spots = FishingSpot.yokohamaYokosuka.map(\.name)
    private let weathers = ["晴れ", "晴れ時々曇り", "曇り", "雨", "風が強い"]
    private let tides = ["大潮", "中潮", "小潮", "長潮", "若潮"]
    private let commonLures = ["0.5g ジグヘッド", "0.8g ジグヘッド", "1.0g ジグヘッド", "1.5g ジグヘッド",
                               "尺ヘッド", "アジリンガー", "アジリンガーPro", "バグアンツ", "その他"]

    var body: some View {
        NavigationStack {
            Form {
                Section("基本情報") {
                    Picker("釣り場", selection: $spotName) {
                        Text("未選択").tag("")
                        ForEach(spots, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    DatePicker("日時", selection: $date)
                }

                Section("釣果") {
                    Stepper("釣果: \(fishCount)匹", value: $fishCount, in: 0...500)
                    HStack {
                        Text("最大サイズ")
                        Spacer()
                        TextField("cm", value: $maxSize, format: .number)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                            .frame(width: 80)
                        Text("cm")
                    }
                }

                Section("釣り条件") {
                    Picker("天気", selection: $weather) {
                        Text("未選択").tag("")
                        ForEach(weathers, id: \.self) { w in
                            Text(w).tag(w)
                        }
                    }
                    Picker("潮回り", selection: $tide) {
                        Text("未選択").tag("")
                        ForEach(tides, id: \.self) { t in
                            Text(t).tag(t)
                        }
                    }
                    Picker("ルアー", selection: $lure) {
                        Text("未選択").tag("")
                        ForEach(commonLures, id: \.self) { l in
                            Text(l).tag(l)
                        }
                    }
                }

                Section("メモ") {
                    TextEditor(text: $memo)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle("釣果を記録")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let record = CatchRecord(
                            date: date,
                            spotName: spotName,
                            fishCount: fishCount,
                            maxSize: maxSize,
                            weather: weather,
                            windDirection: windDirection,
                            tide: tide,
                            lure: lure,
                            memo: memo
                        )
                        onSave(record)
                        dismiss()
                    }
                    .disabled(spotName.isEmpty && fishCount == 0)
                }
            }
        }
    }
}
