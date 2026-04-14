import SwiftUI
import PhotosUI

// MARK: - 入船履歴リスト

struct VesselHistoryView: View {
    @EnvironmentObject var profileStore: VesselProfileStore
    @EnvironmentObject var berthService: BerthMonitorService
    @EnvironmentObject var berthUnlockStore: BerthUnlockStore

    @State private var showAddAlert = false
    @State private var newVesselName = ""

    private var allVesselNames: [String] {
        var names = berthService.vessels.map(\.vesselName)
        for p in profileStore.profiles where !names.contains(p.vesselName) {
            names.append(p.vesselName)
        }
        return names
    }

    var body: some View {
        List {
            if allVesselNames.isEmpty {
                Text("データなし")
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(allVesselNames, id: \.self) { name in
                    let vessel = berthService.vessels.first { $0.vesselName == name }
                    let profile = profileStore.profile(for: name)
                    NavigationLink {
                        VesselProfileView(vesselName: name, vessel: vessel)
                            .environmentObject(profileStore)
                            .environmentObject(berthUnlockStore)
                    } label: {
                        VesselHistoryRow(vesselName: name, vessel: vessel, hasProfile: profile != nil)
                    }
                }
            }
        }
        .navigationTitle("入船履歴")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if berthUnlockStore.isUnlocked {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        newVesselName = ""
                        showAddAlert = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .alert("船舶を追加", isPresented: $showAddAlert) {
            TextField("船舶名", text: $newVesselName)
            Button("追加") {
                let trimmed = newVesselName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty,
                      profileStore.profile(for: trimmed) == nil,
                      !berthService.vessels.contains(where: { $0.vesselName == trimmed })
                else { return }
                profileStore.save(VesselProfile(vesselName: trimmed))
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("スケジュールにない船舶を手動で追加します")
        }
    }
}

// MARK: - 履歴リスト行

struct VesselHistoryRow: View {
    let vesselName: String
    let vessel: VesselInfo?
    let hasProfile: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "ferry.fill")
                .font(.title3)
                .foregroundStyle(.blue.opacity(0.7))
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(vesselName)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                if let v = vessel {
                    Text(vesselStatusLabel(v))
                        .font(.caption)
                        .foregroundStyle(vesselStatusColor(v))
                } else {
                    Text("履歴のみ")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if hasProfile {
                Image(systemName: "info.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
        }
        .padding(.vertical, 2)
    }

    private func vesselStatusLabel(_ v: VesselInfo) -> String {
        if v.isCurrentlyDocked { return "停泊中" }
        if v.isUpcoming { return "入港予定" }
        return "出港済"
    }

    private func vesselStatusColor(_ v: VesselInfo) -> Color {
        if v.isCurrentlyDocked { return .red }
        if v.isUpcoming { return .orange }
        return .secondary
    }
}

// MARK: - 船舶詳細プロフィール

struct VesselProfileView: View {
    let vesselName: String
    let vessel: VesselInfo?

    @EnvironmentObject var profileStore: VesselProfileStore
    @EnvironmentObject var berthUnlockStore: BerthUnlockStore

    @State private var showEdit = false
    @State private var photos: [UIImage] = []

    private var profile: VesselProfile? { profileStore.profile(for: vesselName) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // 写真
                if !photos.isEmpty {
                    photosSection
                } else {
                    HStack {
                        Image(systemName: "photo.on.rectangle")
                            .foregroundStyle(.secondary)
                        Text("写真未登録")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(24)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // 個別情報
                if let p = profile {
                    infoSection(p)
                } else {
                    Text("情報が登録されていません")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(24)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // 現在のスケジュール情報
                if let v = vessel {
                    scheduleSection(v)
                }

                Spacer(minLength: 32)
            }
            .padding()
        }
        .navigationTitle(vesselName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if berthUnlockStore.isUnlocked {
                Button("編集") { showEdit = true }
            }
        }
        .sheet(isPresented: $showEdit, onDismiss: loadPhotos) {
            VesselProfileEditView(vesselName: vesselName)
                .environmentObject(profileStore)
        }
        .onAppear(perform: loadPhotos)
    }

    // MARK: - Photos Section

    private var photosSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("写真")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(photos.enumerated()), id: \.offset) { _, img in
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 160, height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
    }

    // MARK: - Info Section

    private func infoSection(_ p: VesselProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("スポットへの影響")
                .font(.headline)

            VStack(spacing: 0) {
                if !p.brightness.isEmpty {
                    VesselProfileInfoRow(label: "明るさ", value: p.brightness)
                    Divider().padding(.leading, 16)
                }
                if !p.shadowPosition.isEmpty {
                    VesselProfileInfoRow(label: "影の位置", value: p.shadowPosition)
                    Divider().padding(.leading, 16)
                }
                if !p.notes.isEmpty {
                    VesselProfileInfoRow(label: "その他", value: p.notes)
                }
                if p.brightness.isEmpty && p.shadowPosition.isEmpty && p.notes.isEmpty {
                    Text("情報なし")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding()
                }
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 6)

            Text("最終更新: \(p.lastUpdated.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Schedule Section

    private func scheduleSection(_ v: VesselInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("スケジュール")
                .font(.headline)

            VStack(spacing: 0) {
                HStack {
                    Label("入港", systemImage: "arrow.down.to.line")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 60, alignment: .leading)
                    if let d = v.arrivalDate {
                        Text(d.formatted(date: .abbreviated, time: .shortened))
                            .font(.subheadline)
                    } else {
                        Text("不明").font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                Divider().padding(.leading, 16)

                HStack {
                    Label("出港", systemImage: "arrow.up.to.line")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 60, alignment: .leading)
                    if let d = v.departureDate {
                        Text(d.formatted(date: .abbreviated, time: .shortened))
                            .font(.subheadline)
                    } else {
                        Text("未定").font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 6)
        }
    }

    // MARK: - Photo Loading

    private func loadPhotos() {
        guard let p = profile else { photos = []; return }
        photos = p.photoFilenames.compactMap { profileStore.loadPhoto(filename: $0) }
    }
}

// MARK: - 情報行

private struct VesselProfileInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .leading)
            Text(value)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// MARK: - 編集シート（管理者専用）

struct VesselProfileEditView: View {
    let vesselName: String

    @EnvironmentObject var profileStore: VesselProfileStore
    @Environment(\.dismiss) private var dismiss

    @State private var brightness: String = ""
    @State private var shadowPosition: String = ""
    @State private var notes: String = ""
    @State private var keptFilenames: [String] = []
    @State private var keptPhotos: [(filename: String, image: UIImage)] = []
    @State private var newImages: [UIImage] = []
    @State private var pickerItems: [PhotosPickerItem] = []

    var body: some View {
        NavigationStack {
            Form {
                Section("写真") {
                    // 既存写真（削除可能）
                    if !keptPhotos.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(keptPhotos, id: \.filename) { item in
                                    ZStack(alignment: .topTrailing) {
                                        Image(uiImage: item.image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 80, height: 80)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))

                                        Button {
                                            keptPhotos.removeAll { $0.filename == item.filename }
                                            keptFilenames.removeAll { $0 == item.filename }
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(.white, .red)
                                                .font(.title3)
                                        }
                                        .offset(x: 4, y: -4)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }

                    // 新規追加写真プレビュー
                    if !newImages.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Array(newImages.enumerated()), id: \.offset) { i, img in
                                    ZStack(alignment: .topTrailing) {
                                        Image(uiImage: img)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 80, height: 80)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))

                                        Button {
                                            newImages.remove(at: i)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(.white, .red)
                                                .font(.title3)
                                        }
                                        .offset(x: 4, y: -4)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }

                    PhotosPicker(selection: $pickerItems, maxSelectionCount: 5, matching: .images) {
                        Label("写真を追加", systemImage: "photo.badge.plus")
                    }
                    .onChange(of: pickerItems) { loadPickerItems() }
                }

                Section("明るさ") {
                    TextField("例: 夜間は明るい、昼間は影が出る", text: $brightness)
                }

                Section("影の位置") {
                    TextField("例: 船の北側（海側）が暗くなる", text: $shadowPosition)
                }

                Section("その他メモ") {
                    TextField("自由記入", text: $notes, axis: .vertical)
                        .lineLimit(4...)
                }
            }
            .navigationTitle(vesselName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") { saveAndDismiss() }
                        .bold()
                }
            }
            .onAppear(perform: loadExisting)
        }
    }

    private func loadExisting() {
        guard let p = profileStore.profile(for: vesselName) else { return }
        brightness = p.brightness
        shadowPosition = p.shadowPosition
        notes = p.notes
        keptFilenames = p.photoFilenames
        keptPhotos = p.photoFilenames.compactMap { fn in
            guard let img = profileStore.loadPhoto(filename: fn) else { return nil }
            return (filename: fn, image: img)
        }
    }

    private func loadPickerItems() {
        guard !pickerItems.isEmpty else { return }
        Task {
            var loaded: [UIImage] = []
            for item in pickerItems {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let img = UIImage(data: data) {
                    loaded.append(img)
                }
            }
            newImages = loaded
            pickerItems = []
        }
    }

    private func saveAndDismiss() {
        var p = profileStore.profile(for: vesselName) ?? VesselProfile(vesselName: vesselName)

        // 削除された既存写真
        let removedFilenames = p.photoFilenames.filter { !keptFilenames.contains($0) }
        removedFilenames.forEach { profileStore.deletePhoto(filename: $0) }

        // 新規写真を保存
        let newFilenames = newImages.map { profileStore.savePhoto($0, for: vesselName) }

        p.photoFilenames = keptFilenames + newFilenames
        p.brightness = brightness
        p.shadowPosition = shadowPosition
        p.notes = notes
        profileStore.save(p)
        dismiss()
    }
}
