import SwiftUI
import PhotosUI
import UIKit

// MARK: - Main List View

struct CatchLogView: View {
    @EnvironmentObject var store: CatchRecordStore
    @EnvironmentObject var tackleStore: TackleStore
    @EnvironmentObject var shareSettings: ShareSettingsStore
    @EnvironmentObject var berthUnlockStore: BerthUnlockStore
    @EnvironmentObject var berthService: BerthMonitorService
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
                    Button { showAddSheet = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddCatchSheet { record in store.add(record) }
                    .environmentObject(store)
                    .environmentObject(tackleStore)
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
                NavigationLink(destination:
                    CatchDetailView(recordId: record.id)
                        .environmentObject(store)
                        .environmentObject(tackleStore)
                        .environmentObject(shareSettings)
                        .environmentObject(berthUnlockStore)
                        .environmentObject(berthService)
                ) {
                    CatchRecordRow(record: record, store: store)
                }
            }
            .onDelete { store.delete(at: $0) }
        }
        .listStyle(.insetGrouped)
    }

    private var statsSection: some View {
        Section("統計") {
            HStack {
                StatCard(title: "総釣行数", value: "\(store.records.count)回", icon: "calendar.badge.checkmark")
                Spacer()
                StatCard(title: "総釣果", value: "\(store.records.map(\.fishCount).reduce(0, +))匹", icon: "fish.fill")
                Spacer()
                StatCard(title: "最大サイズ", value: "\(String(format: "%.0f", store.records.map(\.maxSize).max() ?? 0))cm", icon: "ruler")
            }
        }
    }
}

// MARK: - Record Row

struct CatchRecordRow: View {
    let record: CatchRecord
    let store: CatchRecordStore

    var body: some View {
        HStack(spacing: 12) {
            // サムネイル（写真があれば）
            if let first = record.photoFilenames.first,
               let img = store.loadPhoto(filename: first) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(record.spotName.isEmpty ? "不明な釣り場" : record.spotName)
                        .font(.headline)
                    Spacer()
                    Text("\(record.fishCount)匹")
                        .font(.title3.bold())
                        .foregroundStyle(.blue)
                }

                HStack(spacing: 6) {
                    Text(record.date, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let range = record.timeRangeLabel {
                        Text(range)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let dur = record.durationLabel {
                            Text("(\(dur))")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                HStack(spacing: 10) {
                    if record.maxSize > 0 {
                        Text("最大\(String(format: "%.0f", record.maxSize))cm")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    if !record.weather.isEmpty {
                        Label(record.weather, systemImage: "cloud.sun")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    if !record.tide.isEmpty {
                        Label(record.tide, systemImage: "water.waves")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Detail View

struct CatchDetailView: View {
    let recordId: UUID
    @EnvironmentObject var store: CatchRecordStore
    @EnvironmentObject var tackleStore: TackleStore
    @EnvironmentObject var shareSettings: ShareSettingsStore
    @EnvironmentObject var berthUnlockStore: BerthUnlockStore
    @EnvironmentObject var berthService: BerthMonitorService

    @State private var photos: [UIImage] = []
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var selectedPhotoIndex: Int? = nil
    @State private var showShareSettings = false
    @State private var showEditSheet = false

    private var record: CatchRecord? {
        store.records.first { $0.id == recordId }
    }

    var body: some View {
        Group {
            if let record {
                content(record: record)
            } else {
                Text("記録が見つかりません").foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func content(record: CatchRecord) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                if !photos.isEmpty { photoGallery }
                infoCard(record: record)
                if let ts = record.tackleSet, !ts.isEmpty { tackleCard(ts) }
                if !record.memo.isEmpty { memoCard(record: record) }
                shareButtons(record: record)
            }
            .padding()
        }
        .navigationTitle(record.spotName.isEmpty ? "釣果詳細" : record.spotName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack {
                    Button { showEditSheet = true } label: {
                        Text("編集")
                    }
                    Button { showShareSettings = true } label: {
                        Image(systemName: "gear")
                    }
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: shareItems)
        }
        .sheet(isPresented: $showShareSettings) {
            ShareSettingsView()
                .environmentObject(shareSettings)
        }
        .sheet(isPresented: $showEditSheet) {
            EditCatchSheet(record: record)
                .environmentObject(store)
                .environmentObject(tackleStore)
                .environmentObject(berthUnlockStore)
                .environmentObject(berthService)
        }
        .task(id: record.photoFilenames) {
            photos = store.loadPhotos(for: record)
        }
        .fullScreenCover(item: Binding(
            get: { selectedPhotoIndex.map { PhotoIndex(value: $0) } },
            set: { selectedPhotoIndex = $0?.value }
        )) { pi in
            PhotoFullscreenView(photos: photos, initialIndex: pi.value)
        }
    }

    // MARK: - Photo Gallery

    private var photoGallery: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(photos.indices, id: \.self) { i in
                    Image(uiImage: photos[i])
                        .resizable()
                        .scaledToFill()
                        .frame(width: 200, height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .onTapGesture { selectedPhotoIndex = i }
                }
            }
            .padding(.horizontal, 2)
        }
    }

    // MARK: - Info Card

    private func infoCard(record: CatchRecord) -> some View {
        VStack(spacing: 0) {
            detailRow(icon: "mappin.circle.fill", color: .red,
                      label: "釣り場", value: record.spotName.isEmpty ? "未設定" : record.spotName)
            Divider().padding(.leading, 40)

            detailRow(icon: "calendar", color: .blue,
                      label: "日付", value: record.date.formatted(.dateTime.year().month().day().weekday()))
            Divider().padding(.leading, 40)

            if let range = record.timeRangeLabel {
                detailRow(icon: "clock.fill", color: .orange,
                          label: "時間", value: range + (record.durationLabel.map { "  (\($0))" } ?? ""))
                Divider().padding(.leading, 40)
            }

            detailRow(icon: "fish.fill", color: .blue,
                      label: "釣果", value: "\(record.fishCount)匹" + (record.maxSize > 0 ? "  最大\(String(format: "%.0f", record.maxSize))cm" : ""))
            Divider().padding(.leading, 40)

            if !record.weather.isEmpty {
                detailRow(icon: "cloud.sun.fill", color: .yellow,
                          label: "天気", value: record.weather)
                Divider().padding(.leading, 40)
            }

            if !record.tide.isEmpty {
                detailRow(icon: "water.waves", color: .teal,
                          label: "潮回り", value: record.tide)
            }

            if !record.dockedVessels.isEmpty {
                Divider().padding(.leading, 40)
                detailRow(icon: "ferry.fill", color: .orange,
                          label: "停泊船", value: record.dockedVessels.joined(separator: "・"))
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8)
    }

    private func detailRow(icon: String, color: Color, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 28)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .leading)
            Text(value)
                .font(.subheadline)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Tackle Card

    private func tackleCard(_ ts: TackleSet) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("使用タックル", systemImage: "latch.2.case.fill")
                .font(.headline)

            VStack(spacing: 0) {
                if let rod = tackleStore.rod(for: ts.rodId) {
                    tackleRow(icon: "arrow.up.right", label: "ロッド", value: rod.displayName)
                    Divider().padding(.leading, 40)
                }
                if let reel = tackleStore.reel(for: ts.reelId) {
                    tackleRow(icon: "circle.circle", label: "リール", value: reel.displayName)
                    Divider().padding(.leading, 40)
                }
                if let line = tackleStore.line(for: ts.lineId) {
                    tackleRow(icon: "line.diagonal", label: "ライン", value: line.displayName)
                    Divider().padding(.leading, 40)
                }
                if let leader = tackleStore.leader(for: ts.leaderId) {
                    tackleRow(icon: "link", label: "リーダー", value: leader.displayName)
                    Divider().padding(.leading, 40)
                }
                if let jh = tackleStore.jigHead(for: ts.jigHeadId) {
                    tackleRow(icon: "diamond.fill", label: "ジグヘッド", value: jh.displayName)
                    Divider().padding(.leading, 40)
                }
                if let worm = tackleStore.worm(for: ts.wormId) {
                    tackleRow(icon: "waveform.path", label: "ワーム", value: worm.displayName)
                }
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8)
    }

    private func tackleRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 28)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .leading)
            Text(value)
                .font(.caption)
                .lineLimit(2)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Memo Card

    private func memoCard(record: CatchRecord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("メモ", systemImage: "note.text")
                .font(.headline)
            Text(record.memo)
                .font(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8)
    }

    // MARK: - Share Buttons

    private func shareButtons(record: CatchRecord) -> some View {
        VStack(spacing: 12) {
            Button {
                shareItems = buildShareItems(record: record)
                showShareSheet = true
            } label: {
                Label("SNS・アプリでシェア", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            HStack(spacing: 12) {
                Button {
                    openX(record: record)
                } label: {
                    HStack {
                        Image(systemName: "x.circle.fill")
                        Text("X で投稿")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.black)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button {
                    shareToInstagramStories(record: record)
                } label: {
                    HStack {
                        Image(systemName: "camera.circle.fill")
                        Text("IG Stories")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.91, green: 0.27, blue: 0.55),
                                     Color(red: 0.97, green: 0.55, blue: 0.27)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Share Logic

    private func buildShareItems(record: CatchRecord) -> [Any] {
        var items: [Any] = [buildShareText(record: record)]
        if let first = photos.first {
            items.append(first)
        }
        return items
    }

    func buildShareText(record: CatchRecord) -> String {
        let s = shareSettings.settings
        var lines: [String] = []

        if !s.headerText.isEmpty {
            lines.append(s.headerText)
            lines.append("")
        }

        if s.includeSpot, !record.spotName.isEmpty {
            lines.append("📍 \(record.spotName)")
        }

        if s.includeDate {
            var dateStr = record.date.formatted(.dateTime.year().month().day())
            if s.includeTime, let range = record.timeRangeLabel {
                dateStr += "  " + range
                if let dur = record.durationLabel { dateStr += "（\(dur)）" }
            }
            lines.append("📅 \(dateStr)")
        }

        var catchParts: [String] = []
        if s.includeFishCount           { catchParts.append("\(record.fishCount)匹") }
        if s.includeMaxSize, record.maxSize > 0 {
            catchParts.append("最大\(String(format: "%.0f", record.maxSize))cm")
        }
        if !catchParts.isEmpty { lines.append("🐟 " + catchParts.joined(separator: "  ")) }

        var condParts: [String] = []
        if s.includeTide,    !record.tide.isEmpty    { condParts.append(record.tide) }
        if s.includeWeather, !record.weather.isEmpty { condParts.append(record.weather) }
        if !condParts.isEmpty { lines.append("🌊 " + condParts.joined(separator: " ｜ ")) }

        if s.includeTackle, let ts = record.tackleSet, !ts.isEmpty {
            var tackleLines: [String] = []
            if s.tackleRod,    let r = tackleStore.rod(for: ts.rodId)          { tackleLines.append("ロッド: \(r.displayName)") }
            if s.tackleReel,   let r = tackleStore.reel(for: ts.reelId)        { tackleLines.append("リール: \(r.displayName)") }
            if s.tackleLine,   let l = tackleStore.line(for: ts.lineId)        { tackleLines.append("ライン: \(l.displayName)") }
            if s.tackleLeader, let l = tackleStore.leader(for: ts.leaderId)    { tackleLines.append("リーダー: \(l.displayName)") }
            if s.tackleJigHead,let j = tackleStore.jigHead(for: ts.jigHeadId) { tackleLines.append("ジグヘッド: \(j.displayName)") }
            if s.tackleWorm,   let w = tackleStore.worm(for: ts.wormId)        { tackleLines.append("ワーム: \(w.displayName)") }
            if !tackleLines.isEmpty {
                lines.append("")
                lines.append("🎣 タックル")
                lines.append(contentsOf: tackleLines)
            }
        }

        if s.includeMemo, !record.memo.isEmpty {
            lines.append("")
            lines.append(record.memo)
        }

        let tag = s.hashtagLine
        if !tag.isEmpty {
            lines.append("")
            lines.append(tag)
        }

        let footer = s.customFooter.trimmingCharacters(in: .whitespacesAndNewlines)
        if !footer.isEmpty {
            lines.append("")
            lines.append(footer)
        }

        return lines.joined(separator: "\n")
    }

    private func openX(record: CatchRecord) {
        let text = buildShareText(record: record)
        let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let xAppURL = URL(string: "twitter://post?message=\(encoded)")!
        let xWebURL = URL(string: "https://x.com/intent/tweet?text=\(encoded)")!
        if UIApplication.shared.canOpenURL(xAppURL) {
            UIApplication.shared.open(xAppURL)
        } else {
            UIApplication.shared.open(xWebURL)
        }
    }

    private func shareToInstagramStories(record: CatchRecord) {
        guard let igURL = URL(string: "instagram-stories://share"),
              UIApplication.shared.canOpenURL(igURL) else {
            shareItems = buildShareItems(record: record)
            showShareSheet = true
            return
        }

        let image = photos.first ?? makeTextImage(record: record)
        guard let imgData = image.jpegData(compressionQuality: 0.9) else { return }

        let pasteboardItems: [[String: Any]] = [[
            "com.instagram.sharedSticker.backgroundImage": imgData
        ]]
        UIPasteboard.general.setItems(pasteboardItems,
            options: [.expirationDate: Date().addingTimeInterval(300)])

        UIApplication.shared.open(igURL)
    }

    private func makeTextImage(record: CatchRecord) -> UIImage {
        let text = buildShareText(record: record)
        let size = CGSize(width: 1080, height: 1920)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor(red: 0.05, green: 0.1, blue: 0.2, alpha: 1).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 52, weight: .medium),
                .foregroundColor: UIColor.white
            ]
            let rect = CGRect(x: 80, y: 200, width: size.width - 160, height: size.height - 400)
            text.draw(in: rect, withAttributes: attrs)
        }
    }
}

// MARK: - Photo Fullscreen

private struct PhotoIndex: Identifiable {
    let value: Int
    var id: Int { value }
}

struct PhotoFullscreenView: View {
    let photos: [UIImage]
    let initialIndex: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            TabView(selection: .constant(initialIndex)) {
                ForEach(photos.indices, id: \.self) { i in
                    Image(uiImage: photos[i])
                        .resizable()
                        .scaledToFit()
                        .tag(i)
                }
            }
            .tabViewStyle(.page)

            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(.white)
                    .padding()
            }
        }
    }
}

// MARK: - UIActivityViewController Wrapper

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Add Catch Sheet

struct AddCatchSheet: View {
    let onSave: (CatchRecord) -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: CatchRecordStore
    @EnvironmentObject var tackleStore: TackleStore
    @EnvironmentObject var berthUnlockStore: BerthUnlockStore
    @EnvironmentObject var berthService: BerthMonitorService

    @State private var selectedVessels: Set<String> = []
    @State private var spotName = ""
    @State private var date = Date()
    @State private var useTimeRange = false
    @State private var startTime = Date()
    @State private var endTime = Date().addingTimeInterval(3600 * 3)
    @State private var fishCount = 0
    @State private var maxSize = 0.0
    @State private var weather = ""
    @State private var tide = ""
    @State private var memo = ""

    // Tackle
    @State private var selectedRodId:     UUID? = nil
    @State private var selectedReelId:    UUID? = nil
    @State private var selectedLineId:    UUID? = nil
    @State private var selectedLeaderId:  UUID? = nil
    @State private var selectedJigHeadId: UUID? = nil
    @State private var selectedWormId:    UUID? = nil

    // Photos
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var pickedImages: [UIImage] = []

    private let newRecordId = UUID()
    private let spots = FishingSpot.yokohamaYokosuka.map(\.name)
    private let weathers = ["晴れ", "晴れ時々曇り", "曇り", "雨", "風が強い"]
    private let tides = ["大潮", "中潮", "小潮", "長潮", "若潮"]

    var body: some View {
        NavigationStack {
            Form {
                // 基本情報
                Section("基本情報") {
                    Picker("釣り場", selection: $spotName) {
                        Text("未選択").tag("")
                        ForEach(spots, id: \.self) { Text($0).tag($0) }
                    }
                    DatePicker("日付", selection: $date, displayedComponents: .date)
                }

                // 時刻
                Section {
                    Toggle("時刻を記録する", isOn: $useTimeRange)
                    if useTimeRange {
                        DatePicker("開始", selection: $startTime, displayedComponents: .hourAndMinute)
                        DatePicker("終了", selection: $endTime, displayedComponents: .hourAndMinute)
                    }
                } header: {
                    Text("釣行時刻")
                }

                // 釣果
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

                // 条件
                Section("釣り条件") {
                    Picker("天気", selection: $weather) {
                        Text("未選択").tag("")
                        ForEach(weathers, id: \.self) { Text($0).tag($0) }
                    }
                    Picker("潮回り", selection: $tide) {
                        Text("未選択").tag("")
                        ForEach(tides, id: \.self) { Text($0).tag($0) }
                    }
                }

                // 停泊船舶（鶴見川河口 + 機能解除時のみ）
                if spotName == "鶴見川河口" && berthUnlockStore.isUnlocked {
                    Section {
                        if berthService.vessels.isEmpty {
                            Text("船舶データなし（バースモニターで更新してください）")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(berthService.vessels) { vessel in
                                Toggle(vessel.vesselName, isOn: Binding(
                                    get: { selectedVessels.contains(vessel.vesselName) },
                                    set: { on in
                                        if on { selectedVessels.insert(vessel.vesselName) }
                                        else  { selectedVessels.remove(vessel.vesselName) }
                                    }
                                ))
                                .font(.subheadline)
                            }
                        }
                    } header: {
                        Text("停泊船舶（MTK0C）")
                    } footer: {
                        Text("釣行中に停泊していた船を選択")
                    }
                }

                // 写真
                Section("写真") {
                    PhotosPicker(
                        selection: $selectedPhotos,
                        maxSelectionCount: 5,
                        matching: .images
                    ) {
                        Label(pickedImages.isEmpty ? "写真を追加" : "\(pickedImages.count)枚選択済",
                              systemImage: "photo.on.rectangle.angled")
                    }
                    if !pickedImages.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(pickedImages.indices, id: \.self) { i in
                                    ZStack(alignment: .topTrailing) {
                                        Image(uiImage: pickedImages[i])
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 80, height: 80)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                        Button {
                                            pickedImages.remove(at: i)
                                            if i < selectedPhotos.count {
                                                selectedPhotos.remove(at: i)
                                            }
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(.white, .black)
                                                .font(.caption)
                                        }
                                        .offset(x: 6, y: -6)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .onChange(of: selectedPhotos) {
                    Task { await loadPhotos() }
                }

                // タックル
                Section("使用タックル") {
                    TacklePickerRow(label: "ロッド",      selectedId: $selectedRodId,     items: tackleStore.rods,     displayName: { $0.displayName })
                    TacklePickerRow(label: "リール",     selectedId: $selectedReelId,    items: tackleStore.reels,    displayName: { $0.displayName })
                    TacklePickerRow(label: "ライン",     selectedId: $selectedLineId,    items: tackleStore.lines,    displayName: { $0.displayName })
                    TacklePickerRow(label: "リーダー",   selectedId: $selectedLeaderId,  items: tackleStore.leaders,  displayName: { $0.displayName })
                    TacklePickerRow(label: "ジグヘッド", selectedId: $selectedJigHeadId, items: tackleStore.jigHeads, displayName: { $0.displayName })
                    TacklePickerRow(label: "ワーム",     selectedId: $selectedWormId,    items: tackleStore.worms,    displayName: { $0.displayName })
                }

                // メモ
                Section("メモ") {
                    TextEditor(text: $memo).frame(minHeight: 80)
                }
            }
            .navigationTitle("釣果を記録")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { saveRecord() }
                        .disabled(spotName.isEmpty && fishCount == 0)
                }
            }
        }
    }

    private func loadPhotos() async {
        var loaded: [UIImage] = []
        for item in selectedPhotos {
            if let data = try? await item.loadTransferable(type: Data.self),
               let img = UIImage(data: data) {
                loaded.append(img)
            }
        }
        await MainActor.run { pickedImages = loaded }
    }

    private func saveRecord() {
        // 写真をDocumentsに保存してファイル名リストを作る
        let filenames = pickedImages.map { store.savePhoto($0, for: newRecordId) }

        // 開始・終了時刻を date と合成
        let calendar = Calendar.current
        let st: Date? = useTimeRange ? calendar.date(
            bySettingHour: calendar.component(.hour, from: startTime),
            minute: calendar.component(.minute, from: startTime),
            second: 0, of: date) : nil
        let et: Date? = useTimeRange ? calendar.date(
            bySettingHour: calendar.component(.hour, from: endTime),
            minute: calendar.component(.minute, from: endTime),
            second: 0, of: date) : nil

        let ts = TackleSet(
            rodId: selectedRodId, reelId: selectedReelId,
            lineId: selectedLineId, leaderId: selectedLeaderId,
            jigHeadId: selectedJigHeadId, wormId: selectedWormId
        )
        let record = CatchRecord(
            id: newRecordId,
            date: date,
            startTime: st,
            endTime: et,
            spotName: spotName,
            fishCount: fishCount,
            maxSize: maxSize,
            weather: weather,
            tide: tide,
            memo: memo,
            tackleSet: ts.isEmpty ? nil : ts,
            photoFilenames: filenames,
            dockedVessels: Array(selectedVessels)
        )
        onSave(record)
        dismiss()
    }
}

// MARK: - Edit Catch Sheet

struct EditCatchSheet: View {
    let record: CatchRecord
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: CatchRecordStore
    @EnvironmentObject var tackleStore: TackleStore
    @EnvironmentObject var berthUnlockStore: BerthUnlockStore
    @EnvironmentObject var berthService: BerthMonitorService

    @State private var selectedVessels: Set<String>
    @State private var spotName: String
    @State private var date: Date
    @State private var useTimeRange: Bool
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var fishCount: Int
    @State private var maxSize: Double
    @State private var weather: String
    @State private var tide: String
    @State private var memo: String

    @State private var selectedRodId:     UUID?
    @State private var selectedReelId:    UUID?
    @State private var selectedLineId:    UUID?
    @State private var selectedLeaderId:  UUID?
    @State private var selectedJigHeadId: UUID?
    @State private var selectedWormId:    UUID?

    // 既存写真（削除可能）
    @State private var keptFilenames: [String]
    @State private var existingPhotos: [UIImage] = []
    // 新規追加写真
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var newImages: [UIImage] = []

    private let spots    = FishingSpot.yokohamaYokosuka.map(\.name)
    private let weathers = ["晴れ", "晴れ時々曇り", "曇り", "雨", "風が強い"]
    private let tides    = ["大潮", "中潮", "小潮", "長潮", "若潮"]

    init(record: CatchRecord) {
        self.record = record
        _selectedVessels = State(initialValue: Set(record.dockedVessels))
        _spotName        = State(initialValue: record.spotName)
        _date            = State(initialValue: record.date)
        _useTimeRange    = State(initialValue: record.startTime != nil)
        _startTime       = State(initialValue: record.startTime ?? record.date)
        _endTime         = State(initialValue: record.endTime ?? record.date.addingTimeInterval(3600 * 3))
        _fishCount       = State(initialValue: record.fishCount)
        _maxSize         = State(initialValue: record.maxSize)
        _weather         = State(initialValue: record.weather)
        _tide            = State(initialValue: record.tide)
        _memo            = State(initialValue: record.memo)
        _keptFilenames   = State(initialValue: record.photoFilenames)
        _selectedRodId     = State(initialValue: record.tackleSet?.rodId)
        _selectedReelId    = State(initialValue: record.tackleSet?.reelId)
        _selectedLineId    = State(initialValue: record.tackleSet?.lineId)
        _selectedLeaderId  = State(initialValue: record.tackleSet?.leaderId)
        _selectedJigHeadId = State(initialValue: record.tackleSet?.jigHeadId)
        _selectedWormId    = State(initialValue: record.tackleSet?.wormId)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本情報") {
                    Picker("釣り場", selection: $spotName) {
                        Text("未選択").tag("")
                        ForEach(spots, id: \.self) { Text($0).tag($0) }
                    }
                    DatePicker("日付", selection: $date, displayedComponents: .date)
                }

                Section {
                    Toggle("時刻を記録する", isOn: $useTimeRange)
                    if useTimeRange {
                        DatePicker("開始", selection: $startTime, displayedComponents: .hourAndMinute)
                        DatePicker("終了", selection: $endTime,   displayedComponents: .hourAndMinute)
                    }
                } header: { Text("釣行時刻") }

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
                        ForEach(weathers, id: \.self) { Text($0).tag($0) }
                    }
                    Picker("潮回り", selection: $tide) {
                        Text("未選択").tag("")
                        ForEach(tides, id: \.self) { Text($0).tag($0) }
                    }
                }

                if spotName == "鶴見川河口" && berthUnlockStore.isUnlocked {
                    Section {
                        if berthService.vessels.isEmpty {
                            Text("船舶データなし（バースモニターで更新してください）")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(berthService.vessels) { vessel in
                                Toggle(vessel.vesselName, isOn: Binding(
                                    get: { selectedVessels.contains(vessel.vesselName) },
                                    set: { on in
                                        if on { selectedVessels.insert(vessel.vesselName) }
                                        else  { selectedVessels.remove(vessel.vesselName) }
                                    }
                                ))
                                .font(.subheadline)
                            }
                        }
                    } header: {
                        Text("停泊船舶（MTK0C）")
                    } footer: {
                        Text("釣行中に停泊していた船を選択")
                    }
                }

                Section("写真") {
                    // 既存写真
                    if !existingPhotos.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(keptFilenames.indices, id: \.self) { i in
                                    if i < existingPhotos.count {
                                        ZStack(alignment: .topTrailing) {
                                            Image(uiImage: existingPhotos[i])
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 80, height: 80)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                            Button {
                                                keptFilenames.remove(at: i)
                                                existingPhotos.remove(at: i)
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundStyle(.white, .black)
                                                    .font(.caption)
                                            }
                                            .offset(x: 6, y: -6)
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    // 新規写真追加
                    PhotosPicker(
                        selection: $selectedPhotos,
                        maxSelectionCount: 5,
                        matching: .images
                    ) {
                        Label(newImages.isEmpty ? "写真を追加" : "追加: \(newImages.count)枚",
                              systemImage: "photo.on.rectangle.angled")
                    }
                    if !newImages.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(newImages.indices, id: \.self) { i in
                                    ZStack(alignment: .topTrailing) {
                                        Image(uiImage: newImages[i])
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 80, height: 80)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                        Button {
                                            newImages.remove(at: i)
                                            if i < selectedPhotos.count {
                                                selectedPhotos.remove(at: i)
                                            }
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(.white, .black)
                                                .font(.caption)
                                        }
                                        .offset(x: 6, y: -6)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .onChange(of: selectedPhotos) {
                    Task { await loadNewPhotos() }
                }

                Section("使用タックル") {
                    TacklePickerRow(label: "ロッド",      selectedId: $selectedRodId,     items: tackleStore.rods,     displayName: { $0.displayName })
                    TacklePickerRow(label: "リール",     selectedId: $selectedReelId,    items: tackleStore.reels,    displayName: { $0.displayName })
                    TacklePickerRow(label: "ライン",     selectedId: $selectedLineId,    items: tackleStore.lines,    displayName: { $0.displayName })
                    TacklePickerRow(label: "リーダー",   selectedId: $selectedLeaderId,  items: tackleStore.leaders,  displayName: { $0.displayName })
                    TacklePickerRow(label: "ジグヘッド", selectedId: $selectedJigHeadId, items: tackleStore.jigHeads, displayName: { $0.displayName })
                    TacklePickerRow(label: "ワーム",     selectedId: $selectedWormId,    items: tackleStore.worms,    displayName: { $0.displayName })
                }

                Section("メモ") {
                    TextEditor(text: $memo).frame(minHeight: 80)
                }
            }
            .navigationTitle("釣果を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { saveRecord() }
                }
            }
            .task {
                existingPhotos = store.loadPhotos(for: record)
            }
        }
    }

    private func loadNewPhotos() async {
        var loaded: [UIImage] = []
        for item in selectedPhotos {
            if let data = try? await item.loadTransferable(type: Data.self),
               let img = UIImage(data: data) {
                loaded.append(img)
            }
        }
        await MainActor.run { newImages = loaded }
    }

    private func saveRecord() {
        // 削除された既存写真をファイルから消す
        let removedFilenames = record.photoFilenames.filter { !keptFilenames.contains($0) }
        store.deletePhotos(filenames: removedFilenames)

        // 新規写真を保存
        let newFilenames = newImages.map { store.savePhoto($0, for: record.id) }
        let allFilenames = keptFilenames + newFilenames

        let calendar = Calendar.current
        let st: Date? = useTimeRange ? calendar.date(
            bySettingHour: calendar.component(.hour, from: startTime),
            minute: calendar.component(.minute, from: startTime),
            second: 0, of: date) : nil
        let et: Date? = useTimeRange ? calendar.date(
            bySettingHour: calendar.component(.hour, from: endTime),
            minute: calendar.component(.minute, from: endTime),
            second: 0, of: date) : nil

        let ts = TackleSet(
            rodId: selectedRodId, reelId: selectedReelId,
            lineId: selectedLineId, leaderId: selectedLeaderId,
            jigHeadId: selectedJigHeadId, wormId: selectedWormId
        )
        var updated = record
        updated.date          = date
        updated.startTime     = st
        updated.endTime       = et
        updated.spotName      = spotName
        updated.fishCount     = fishCount
        updated.maxSize       = maxSize
        updated.weather       = weather
        updated.tide          = tide
        updated.memo          = memo
        updated.tackleSet      = ts.isEmpty ? nil : ts
        updated.photoFilenames = allFilenames
        updated.dockedVessels  = Array(selectedVessels)

        store.update(updated)
        dismiss()
    }
}

// MARK: - Helpers

struct StatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
            Text(value).font(.headline.bold())
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct TacklePickerRow<T: Identifiable & Hashable>: View where T.ID == UUID {
    let label: String
    @Binding var selectedId: UUID?
    let items: [T]
    let displayName: (T) -> String

    var body: some View {
        Picker(label, selection: $selectedId) {
            Text("未選択").tag(UUID?.none)
            ForEach(items) { item in
                Text(displayName(item)).tag(UUID?.some(item.id))
            }
        }
        .lineLimit(1)
    }
}
