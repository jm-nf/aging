import SwiftUI

struct ReelsCreatorView: View {
    let record: CatchRecord
    @EnvironmentObject var store: CatchRecordStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPhotoIndices: Set<Int> = []
    @State private var textOptions = ReelsTextOptions()
    @State private var isExporting = false
    @State private var exportedURL: URL?
    @State private var showShareSheet = false
    @State private var errorMessage: String?

    private func makeTextOptions() -> ReelsTextOptions {
        var opt = ReelsTextOptions()
        opt.spotName  = record.spotName
        opt.catchText = record.fishCount > 0 ? "\(record.fishCount)匹" : ""
        opt.tideText  = record.tide
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "ja_JP")
        fmt.dateStyle = .short
        fmt.timeStyle = .none
        opt.dateText  = fmt.string(from: record.startTime ?? record.date)
        return opt
    }

    private var selectedPhotos: [UIImage] {
        record.photoFilenames.enumerated()
            .filter { selectedPhotoIndices.contains($0.offset) }
            .compactMap { _, name in store.loadPhoto(filename: name) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("写真を選ぶ（複数選択可）") {
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(Array(record.photoFilenames.enumerated()), id: \.offset) { i, name in
                                if let img = store.loadPhoto(filename: name) {
                                    ZStack(alignment: .topTrailing) {
                                        Image(uiImage: img)
                                            .resizable().scaledToFill()
                                            .frame(width: 100, height: 130)
                                            .clipped().cornerRadius(8)
                                            .opacity(selectedPhotoIndices.contains(i) ? 1.0 : 0.4)
                                        if selectedPhotoIndices.contains(i) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(.white, .blue)
                                                .padding(4)
                                        }
                                    }
                                    .onTapGesture {
                                        if selectedPhotoIndices.contains(i) {
                                            selectedPhotoIndices.remove(i)
                                        } else {
                                            selectedPhotoIndices.insert(i)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("テキスト表示") {
                    Toggle("📍 釣り場: \(textOptions.spotName)",  isOn: $textOptions.showSpot)
                    Toggle("📅 日付: \(textOptions.dateText)",    isOn: $textOptions.showDate)
                    Toggle("🐟 釣果: \(textOptions.catchText)",   isOn: $textOptions.showCatch)
                    Toggle("🌊 潮回り: \(textOptions.tideText)",  isOn: $textOptions.showTide)
                }

                if let err = errorMessage {
                    Section {
                        Text(err).foregroundStyle(.red).font(.caption)
                    }
                }
            }
            .navigationTitle("Reels作成")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await exportAndShare() }
                    } label: {
                        if isExporting {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Label("Reels生成", systemImage: "film")
                        }
                    }
                    .disabled(selectedPhotoIndices.isEmpty || isExporting)
                }
            }
            .onAppear { textOptions = makeTextOptions() }
            .sheet(isPresented: $showShareSheet) {
                if let url = exportedURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }

    private func exportAndShare() async {
        let photos = selectedPhotos
        guard !photos.isEmpty else { return }
        isExporting = true
        errorMessage = nil
        do {
            let url = try await ReelsExporter.shared.export(photos: photos, textOptions: textOptions)
            exportedURL = url
            showShareSheet = true
        } catch {
            errorMessage = "動画生成失敗: \(error.localizedDescription)"
        }
        isExporting = false
    }
}
